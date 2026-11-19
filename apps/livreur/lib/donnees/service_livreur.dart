import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/erreurs.dart';
import 'modeles.dart';

/// Données lues et écrites par l'appli livreur (remplaçable dans les tests).
abstract class ServiceLivreur {
  /// Compte du livreur connecté : validation, disponibilité, véhicule, documents.
  Future<EtatLivreur> monEtat();

  /// Véhicule et documents de la candidature (US25). Les photos vont dans le
  /// stockage privé `documents-livreurs/<id>/<type>.<ext>`.
  Future<void> envoyerCandidature({
    required TypeVehicule vehicule,
    String? immatriculation,
    required Map<TypeDocument, DocumentChoisi> documents,
  });

  /// Disponible / indisponible (US26), enregistré dans la base.
  Future<void> definirDisponible(bool disponible);

  /// Courses proposées, sans livreur (US27) : la base ne les montre qu'aux
  /// livreurs validés et disponibles.
  Future<List<Course>> coursesProposees();

  /// Course acceptée et pas encore livrée, s'il y en a une.
  Future<Course?> courseEnCours();
  Future<Course> course(String id);

  Future<void> accepterCourse(String id);
  Future<void> recupererCourse(String id);
  Future<void> livrerCourse(String id);

  /// Appelle [rappel] à chaque changement des courses ou des commandes
  /// (temps réel). Renvoie de quoi se désabonner.
  void Function() surChangements(void Function() rappel);

  /// Courses livrées par le livreur connecté, de la plus récente à la plus ancienne (US42).
  Future<List<Course>> mesCourses();

  /// Note moyenne laissée par les clients (US38).
  Future<NoteLivreur> maNote();
}

class ServiceLivreurSupabase implements ServiceLivreur {
  ServiceLivreurSupabase(this._client);
  final SupabaseClient _client;

  String get _moi {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const ErreurMida('Votre session a expiré. Reconnectez-vous.');
    return id;
  }

  @override
  Future<EtatLivreur> monEtat() async {
    final id = _moi;
    final p = await _client.from('profiles').select('nom, etat_compte').eq('id', id).single();
    final l = await _client
        .from('livreurs')
        .select('disponible, type_vehicule, immatriculation')
        .eq('id', id)
        .maybeSingle();
    final docs = await _client.from('documents_livreur').select('type, etat').eq('livreur_id', id);
    return EtatLivreur(
      nom: p['nom'] as String,
      etatCompte: p['etat_compte'] as String,
      disponible: l?['disponible'] as bool? ?? false,
      typeVehicule: TypeVehicule.depuis(l?['type_vehicule'] as String?),
      immatriculation: l?['immatriculation'] as String?,
      documents: {for (final d in docs) d['type'] as String: d['etat'] as String},
    );
  }

  @override
  Future<void> envoyerCandidature({
    required TypeVehicule vehicule,
    String? immatriculation,
    required Map<TypeDocument, DocumentChoisi> documents,
  }) async {
    final id = _moi;
    await _client
        .from('livreurs')
        .update({'type_vehicule': vehicule.code, 'immatriculation': vehicule.motorise ? immatriculation : null})
        .eq('id', id);
    for (final MapEntry(key: type, value: doc) in documents.entries) {
      final chemin = '$id/${type.code}.${doc.extension}';
      await _client.storage.from('documents-livreurs').uploadBinary(
            chemin,
            doc.octets,
            fileOptions: FileOptions(contentType: doc.typeMime, upsert: true),
          );
      // Remplacement d'un document pas encore validé : l'ancienne ligne est retirée
      // (règle « suppression avant validation » d'US02), la nouvelle attend la validation.
      await _client.from('documents_livreur').delete().eq('livreur_id', id).eq('type', type.code);
      await _client.from('documents_livreur').insert({'livreur_id': id, 'type': type.code, 'fichier_url': chemin});
    }
  }

  @override
  Future<void> definirDisponible(bool disponible) async {
    await _client.from('livreurs').update({'disponible': disponible}).eq('id', _moi);
  }

  @override
  Future<List<Course>> coursesProposees() async {
    final lignes = await _client
        .from('livraisons')
        .select(Course.colonnes)
        .eq('etat', 'proposee')
        .isFilter('livreur_id', null)
        .order('created_at');
    return [for (final l in lignes) Course.depuis(l)];
  }

  @override
  Future<Course?> courseEnCours() async {
    final l = await _client
        .from('livraisons')
        .select(Course.colonnes)
        .eq('livreur_id', _moi)
        .inFilter('etat', ['acceptee', 'recuperee'])
        .maybeSingle();
    return l == null ? null : Course.depuis(l);
  }

  @override
  Future<Course> course(String id) async {
    final l = await _client.from('livraisons').select(Course.colonnes).eq('id', id).single();
    return Course.depuis(l);
  }

  // Fonctions de la base (migration 20261118000001) : elles vérifient tout
  // (livreur validé et disponible, une seule course à la fois, commande prête…).
  @override
  Future<void> accepterCourse(String id) => _client.rpc('accepter_course', params: {'p_livraison': id});

  @override
  Future<void> recupererCourse(String id) => _client.rpc('recuperer_course', params: {'p_livraison': id});

  @override
  Future<void> livrerCourse(String id) => _client.rpc('livrer_course', params: {'p_livraison': id});

  var _canaux = 0;

  @override
  void Function() surChangements(void Function() rappel) {
    // La règle d'accès s'applique aussi au temps réel : seules les courses et
    // commandes visibles par ce livreur arrivent.
    final canal = _client
        .channel('livreur-${_canaux++}')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'livraisons', callback: (_) => rappel())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'commandes', callback: (_) => rappel())
        .subscribe((statut, _) {
      if (statut == RealtimeSubscribeStatus.subscribed) rappel();
    });
    return () => _client.removeChannel(canal);
  }

  @override
  Future<List<Course>> mesCourses() async {
    final lignes = await _client
        .from('livraisons')
        .select(Course.colonnes)
        .eq('livreur_id', _moi)
        .eq('etat', 'livree')
        .order('livree_le', ascending: false)
        .limit(200);
    return [for (final l in lignes) Course.depuis(l)];
  }

  @override
  Future<NoteLivreur> maNote() async {
    // Les avis sont publics (US02) ; seules les notes de ce livreur sont lues.
    final lignes = await _client.from('avis').select('note').eq('livreur_id', _moi);
    return NoteLivreur.depuis(lignes);
  }
}
