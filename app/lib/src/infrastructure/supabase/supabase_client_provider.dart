import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client Supabase partagé (initialisé dans main.dart) : réservé à la composition et aux adaptateurs d'infrastructure.
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
