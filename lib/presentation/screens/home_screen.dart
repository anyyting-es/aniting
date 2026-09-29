import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/settings_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/server_status_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedStatus = 'CURRENT'; // CURRENT, PLANNING, COMPLETED

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(serverNotifierProvider);
    final collectionAsync = ref.watch(animeCollectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icons/logo.png',
                width: 28,
                height: 28,
                cacheWidth: 56,
                cacheHeight: 56,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Aniting'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Escanear Biblioteca',
            icon: const Icon(Icons.sync),
            onPressed: serverState.isOnline
                ? () async {
                    final repo = ref.read(repositoryProvider);
                    final ok = await repo.scanLibrary();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Escaneo iniciado...' : 'Error al iniciar escaneo'),
                        ),
                      );
                    }
                  }
                : null,
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                SlideRightToLeftPageRoute(child: const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ServerStatusBanner(
            onOpenSettings: () {
              Navigator.push(
                context,
                SlideRightToLeftPageRoute(child: const SettingsScreen()),
              );
            },
          ),
          if (serverState.isOnline) ...[
            // Status filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Viendo',
                    selected: _selectedStatus == 'CURRENT',
                    onSelected: () => setState(() => _selectedStatus = 'CURRENT'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Planeados',
                    selected: _selectedStatus == 'PLANNING',
                    onSelected: () => setState(() => _selectedStatus = 'PLANNING'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Completados',
                    selected: _selectedStatus == 'COMPLETED',
                    onSelected: () => setState(() => _selectedStatus = 'COMPLETED'),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: !serverState.isOnline
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'El servidor Seanime no está conectado',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Inicia el servidor local o conecta a tu PC en Ajustes',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              SlideRightToLeftPageRoute(child: const SettingsScreen()),
                            );
                          },
                          child: const Text('Abrir Ajustes de Servidor'),
                        ),
                      ],
                    ),
                  )
                : collectionAsync.when(
                    data: (entries) {
                      final filtered = entries.where((e) {
                        if (_selectedStatus == 'CURRENT') {
                          return e.status == 'CURRENT' || e.status == 'WATCHING';
                        }
                        return e.status == _selectedStatus;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.folder_open, size: 56, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                entries.isEmpty
                                    ? 'No hay animes en tu biblioteca local aún'
                                    : 'No hay animes en esta categoría',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => ref.invalidate(animeCollectionProvider),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Actualizar'),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(animeCollectionProvider);
                        },
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.52,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return AnimeCard(entry: filtered[index]);
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(
                      child: Text('Error al cargar animes: $err'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFF8B5CF6),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.grey,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}
