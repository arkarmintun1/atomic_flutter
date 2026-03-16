import 'package:atomic_flutter_devtools_extension/src/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Detail view for a selected atom — shows full value, metadata,
/// and async state information.
class AtomDetailView extends StatelessWidget {
  final AtomDetailData detail;
  final VoidCallback onClose;

  const AtomDetailView({
    super.key,
    required this.detail,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          child: Row(
            children: [
              Icon(
                detail.isAsync ? Icons.sync : Icons.blur_circular,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  detail.id,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                tooltip: 'Close detail',
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildSection(theme, 'Type', detail.type),
              const SizedBox(height: 12),
              _buildValueSection(context, theme),
              const SizedBox(height: 12),
              _buildMetadataSection(theme),
              if (detail.isAsync) ...[
                const SizedBox(height: 12),
                _buildAsyncSection(theme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildValueSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Current Value',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 14),
              tooltip: 'Copy value',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: detail.value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Value copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: SelectableText(
            detail.value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Metadata',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _MetadataRow(label: 'Ref Count', value: '${detail.refCount}'),
        _MetadataRow(
            label: 'Has Listeners', value: detail.hasListeners ? 'Yes' : 'No'),
        _MetadataRow(
            label: 'Auto Dispose', value: detail.autoDispose ? 'Yes' : 'No'),
        if (detail.disposeTimeoutMs != null)
          _MetadataRow(
            label: 'Dispose Timeout',
            value: '${detail.disposeTimeoutMs}ms',
          ),
      ],
    );
  }

  Widget _buildAsyncSection(ThemeData theme) {
    final (stateLabel, stateColor) = _asyncStateInfo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Async State',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _MetadataRow(
          label: 'State',
          valueWidget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: stateColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              stateLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: stateColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (detail.hasData != null)
          _MetadataRow(
              label: 'Has Data', value: detail.hasData! ? 'Yes' : 'No'),
        if (detail.hasError == true && detail.error != null) ...[
          _MetadataRow(label: 'Has Error', value: 'Yes'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Text(
              detail.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ],
    );
  }

  (String, Color) _asyncStateInfo() {
    return switch (detail.asyncState) {
      'idle' => ('Idle', Colors.grey),
      'loading' => ('Loading', Colors.blue),
      'success' => ('Success', Colors.green),
      'error' => ('Error', Colors.red),
      _ => (detail.asyncState ?? 'Unknown', Colors.grey),
    };
  }
}

class _MetadataRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const _MetadataRow({required this.label, this.value, this.valueWidget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
