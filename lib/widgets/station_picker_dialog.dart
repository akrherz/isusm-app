import 'package:flutter/material.dart';

import '../models/station.dart';

class StationPickerDialog extends StatefulWidget {
  const StationPickerDialog({
    required this.stations,
    required this.selectedStationIds,
    super.key,
  });

  final List<Station> stations;
  final Set<String> selectedStationIds;

  @override
  State<StationPickerDialog> createState() => _StationPickerDialogState();
}

class _StationPickerDialogState extends State<StationPickerDialog> {
  late final TextEditingController _searchController;
  late final Set<String> _selectedStationIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedStationIds = Set<String>.of(widget.selectedStationIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Station> get _visibleStations {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.stations;
    return widget.stations
        .where(
          (station) =>
              station.name.toLowerCase().contains(query) ||
              station.id.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleStations = _visibleStations;
    return AlertDialog(
      title: Text('Choose stations (${_selectedStationIds.length} selected)'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search stations',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (query) => setState(() => _query = query),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visibleStations.isEmpty
                  ? Center(child: Text('No stations match "$_query".'))
                  : ListView.builder(
                      itemCount: visibleStations.length,
                      itemBuilder: (context, index) {
                        final station = visibleStations[index];
                        return CheckboxListTile(
                          value: _selectedStationIds.contains(station.id),
                          title: Text(station.name),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (selected) => setState(() {
                            if (selected ?? false) {
                              _selectedStationIds.add(station.id);
                            } else {
                              _selectedStationIds.remove(station.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedStationIds),
          child: const Text('Done'),
        ),
      ],
    );
  }
}