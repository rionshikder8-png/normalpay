import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'transaction_detail.dart';

/// Transactions tab: payment history (server feed when available) plus the
/// APS reference-ID generator.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum _PeriodMode { today, yesterday, last7, custom }

class _PeriodFilter {
  const _PeriodFilter(this.mode, {this.range});

  final _PeriodMode mode;
  final DateTimeRange? range;

  String get label => switch (mode) {
        _PeriodMode.today => 'Today',
        _PeriodMode.yesterday => 'Yesterday',
        _PeriodMode.last7 => 'Last 7 days',
        _PeriodMode.custom => range == null
            ? 'Custom'
            : '${DateFormat('d MMM').format(range!.start)} - ${DateFormat('d MMM').format(range!.end)}',
      };
}

/// Sheet result: [filter] null means "reset to all time".
class _PeriodResult {
  const _PeriodResult(this.filter);

  final _PeriodFilter? filter;
}

class _PickerResult {
  const _PickerResult(this.id);

  final String? id;
}

class _DayGroup {
  const _DayGroup(this.label, this.items);

  final String label;
  final List<TxItem> items;
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  AppState? _app;
  int _tab = 0;
  TxStatus? _status;
  final Set<GatewayId> _gateways = <GatewayId>{};
  _PeriodFilter? _period;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels < pos.maxScrollExtent - 320) return;
    final appState = _app;
    if (appState != null && appState.txHasMore && !appState.txLoading) {
      appState.loadTransactions();
    }
  }

  // --------------------------------------------------------------- filtering
  bool _matchesSearch(TxItem t) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = <String>[
      t.id,
      t.providerTrxId ?? '',
      t.senderNumber ?? '',
      t.apsReference ?? '',
      t.gateway?.label ?? '',
      t.amount.toString(),
      t.amount.toStringAsFixed(2),
      statusLabel(t.status),
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }

  bool _matchesPeriod(TxItem t) {
    final p = _period;
    if (p == null) return true;
    final d = t.smsReceivedAt;
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    return switch (p.mode) {
      _PeriodMode.today => day == today,
      _PeriodMode.yesterday => today.difference(day).inDays == 1,
      _PeriodMode.last7 => today.difference(day).inDays >= 0 && today.difference(day).inDays < 7,
      _PeriodMode.custom => p.range != null &&
          !day.isBefore(DateTime(p.range!.start.year, p.range!.start.month, p.range!.start.day)) &&
          !day.isAfter(DateTime(p.range!.end.year, p.range!.end.month, p.range!.end.day)),
    };
  }

  List<TxItem> _visible(List<TxItem> source) {
    final seen = <String>{};
    final out = <TxItem>[];
    for (final t in source) {
      if (!seen.add(t.id)) continue;
      if (_status != null && t.status != _status) continue;
      if (_gateways.isNotEmpty && (t.gateway == null || !_gateways.contains(t.gateway))) continue;
      if (!_matchesPeriod(t)) continue;
      if (!_matchesSearch(t)) continue;
      out.add(t);
    }
    out.sort((a, b) {
      final x = a.smsReceivedAt;
      final y = b.smsReceivedAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });
    return out;
  }

  List<_DayGroup> _group(List<TxItem> items) {
    final map = <String, List<TxItem>>{};
    for (final t in items) {
      final at = t.smsReceivedAt;
      final key = at == null ? 'Date unknown' : dayGroup(at);
      map.putIfAbsent(key, () => <TxItem>[]).add(t);
    }
    return [
      for (final entry in map.entries) _DayGroup(entry.key, entry.value),
    ];
  }

  // ----------------------------------------------------------------- actions
  Future<void> _openPeriodSheet() async {
    final result = await showModalBottomSheet<_PeriodResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PeriodSheet(initial: _period),
    );
    if (!mounted || result == null) return;
    setState(() => _period = result.filter);
  }

  void _openDetail(TxItem tx) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TransactionDetailScreen(tx)),
    );
  }

  // ------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    _app = appState;
    return Scaffold(
      backgroundColor: ApsColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Transactions', style: ApsText.title)),
                      if (_tab == 0 && appState.transactions.isNotEmpty)
                        Text('${appState.transactions.length}', style: ApsText.caption),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(value: 0, label: Text('History')),
                      ButtonSegment<int>(value: 1, label: Text('Reference IDs')),
                    ],
                    selected: <int>{_tab},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() => _tab = selection.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                        (states) => states.contains(WidgetState.selected) ? ApsColors.infoBg : ApsColors.card,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                        (states) => states.contains(WidgetState.selected) ? ApsColors.primary : ApsColors.muted,
                      ),
                      side: const WidgetStatePropertyAll<BorderSide>(BorderSide(color: ApsColors.border)),
                      textStyle: const WidgetStatePropertyAll<TextStyle>(
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _tab == 0 ? _history(appState) : const _ReferenceTab()),
              ],
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ history
  Widget _history(AppState appState) {
    final Widget filters = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            style: ApsText.body,
            decoration: InputDecoration(
              hintText: 'Search TrxID, sender, amount, APS ref',
              hintStyle: ApsText.caption,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: ApsColors.muted),
              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: ApsColors.muted),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _Chip(
                        'All',
                        selected: _status == null,
                        onTap: () => setState(() => _status = null),
                      ),
                      for (final s in const [
                        TxStatus.verified,
                        TxStatus.pending,
                        TxStatus.unmatched,
                        TxStatus.duplicate,
                      ])
                        _Chip(
                          statusLabel(s),
                          selected: _status == s,
                          onTap: () => setState(() => _status = _status == s ? null : s),
                        ),
                      const Container(
                        width: 1,
                        height: 18,
                        color: ApsColors.border,
                        margin: EdgeInsets.only(right: 8),
                      ),
                      for (final g in GatewayId.values)
                        _Chip(
                          g.label,
                          selected: _gateways.contains(g),
                          onTap: () => setState(() {
                            if (!_gateways.remove(g)) _gateways.add(g);
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _periodButton(),
            ],
          ),
        ],
      ),
    );

    return Column(
      children: [
        filters,
        Expanded(child: _historyBody(appState)),
      ],
    );
  }

  Widget _periodButton() {
    final active = _period != null;
    final fg = active ? ApsColors.primary : ApsColors.muted;
    return Material(
      color: active ? ApsColors.infoBg : ApsColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _openPeriodSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? ApsColors.primary.withValues(alpha: 0.35) : ApsColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: fg),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  _period?.label ?? 'Period',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyBody(AppState appState) {
    if (appState.transactions.isEmpty) {
      if (appState.txState == ApiState.notAvailable) {
        return _scrollable(
          const EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Transaction history is not available yet',
            message:
                'The APS server does not expose a transaction feed to the Reader yet. Payments are still detected and uploaded.',
          ),
          appState,
        );
      }
      if (appState.txState == ApiState.unauthorized) {
        return _scrollable(
          const EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Device not authorised',
            message: 'This device was revoked or its credentials are no longer valid. Pair it again to continue.',
          ),
          appState,
        );
      }
      if (appState.txState == ApiState.offline || appState.txState == ApiState.error) {
        return _scrollable(
          EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load transactions',
            message: appState.online
                ? 'The server did not return the transaction feed. Try again in a moment.'
                : 'You appear to be offline. Payments are still detected and queued on this device.',
            action: OutlinedButton(
              onPressed: () => appState.loadTransactions(reset: true),
              child: const Text('Retry'),
            ),
          ),
          appState,
        );
      }
      if (appState.txLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return _scrollable(
        const EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No transactions found',
          message: 'New payments detected by APS Reader will appear here.',
        ),
        appState,
      );
    }

    final items = _visible(appState.transactions);
    if (items.isEmpty) {
      return _scrollable(
        EmptyState(
          icon: Icons.filter_alt_off_rounded,
          title: 'No matching transactions',
          message: 'Nothing matches your current search and filters.',
          action: OutlinedButton(
            onPressed: () {
              _search.clear();
              setState(() {
                _status = null;
                _gateways.clear();
                _period = null;
              });
            },
            child: const Text('Clear filters'),
          ),
        ),
        appState,
      );
    }

    final groups = _group(items);
    final showFooter = appState.txHasMore || appState.txLoading;

    return RefreshIndicator(
      color: ApsColors.primary,
      onRefresh: () async {
        await appState.loadTransactions(reset: true);
      },
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
        itemCount: groups.length + (showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= groups.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final g = groups[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
                child: Text(
                  g.label,
                  style: ApsText.bodyBold.copyWith(
                    fontSize: 12.5,
                    color: const Color(0xFF1F3A5F),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              ApsCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < g.items.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      TxTile(g.items[i], onTap: () => _openDetail(g.items[i])),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _scrollable(Widget child, AppState appState) {
    return RefreshIndicator(
      color: ApsColors.primary,
      onRefresh: () async {
        await appState.loadTransactions(reset: true);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [child],
      ),
    );
  }

}

/// Scrollable wrapper for the Reference IDs segment.
class _ReferenceTab extends StatelessWidget {
  const _ReferenceTab();

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 2, 16, 24),
        child: ReferenceGeneratorSection(),
      );
}

// ---------------------------------------------------------------------------
// Reference ID generator
// ---------------------------------------------------------------------------

class ReferenceGeneratorSection extends StatefulWidget {
  const ReferenceGeneratorSection({super.key});

  @override
  State<ReferenceGeneratorSection> createState() => _ReferenceGeneratorSectionState();
}

class _ReferenceGeneratorSectionState extends State<ReferenceGeneratorSection> {
  String? _linkedTxId;
  bool _generating = false;

  Future<void> _generate() async {
    if (_generating) return;
    final appState = AppScope.of(context);
    setState(() => _generating = true);
    try {
      final RefEntry entry = await appState.generateReference(linkTx: _linkedTxId);
      if (!mounted) return;
      copyToClipboard(context, entry.ref, label: 'Reference ID copied');
    } finally {
      // Keep the button disabled for a short window so a double tap cannot
      // create two references.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _pickLink(List<TxItem> items) async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TxPickerSheet(items: items, selected: _linkedTxId),
    );
    if (!mounted || result == null) return;
    setState(() => _linkedTxId = result.id);
  }

  String _txLabel(TxItem tx) {
    final trx = tx.providerTrxId ?? tx.id;
    return '${tx.gateway?.label ?? 'Payment'} - $trx - ${taka(tx.amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final refs = appState.references;
        final newest = refs.isEmpty ? null : refs.first;
        final linked = _linkedTxId == null ? null : appState.findTx(_linkedTxId);
        final txs = appState.transactions;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ApsCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: ApsColors.warnBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline_rounded, size: 18, color: ApsColors.warn),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'An APS Reference ID is an internal reference. It is NOT a bKash, Nagad, Rocket or Upay transaction ID and never marks a payment as completed.',
                      style: ApsText.label,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ApsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(_generating ? 'Generating...' : 'Generate New ID'),
                  ),
                  if (newest != null) ...[
                    const SizedBox(height: 16),
                    const Text('Newest reference', style: ApsText.caption),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SelectableText(
                            newest.ref,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: ApsColors.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded, size: 18, color: ApsColors.primary),
                          onPressed: () => copyToClipboard(context, newest.ref, label: 'Reference ID copied'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: newest.serverConfirmed
                              ? const StatusPill('Server issued', fg: ApsColors.success, bg: ApsColors.successBg)
                              : const StatusPill(
                                  'Local reference (not globally unique)',
                                  fg: ApsColors.warn,
                                  bg: ApsColors.warnBg,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(dateTime(newest.at), style: ApsText.caption),
                    if (newest.linkedTx != null)
                      Text('Linked to ${newest.linkedTx}', style: ApsText.caption),
                  ],
                ],
              ),
            ),
            if (txs.isNotEmpty) ...[
              const SizedBox(height: 12),
              ApsCard(
                onTap: () => _pickLink(txs),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 18, color: ApsColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Link to transaction', style: ApsText.bodyBold),
                          const SizedBox(height: 2),
                          Text(
                            linked == null ? 'Not linked' : _txLabel(linked),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ApsText.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: ApsColors.muted),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            ApsCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Reference history', style: ApsText.bodyBold)),
                      Text('${refs.length}', style: ApsText.caption),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (refs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('No reference IDs generated on this device yet.', style: ApsText.caption),
                    )
                  else
                    for (var i = 0; i < refs.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _refRow(context, refs[i]),
                    ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _refRow(BuildContext context, RefEntry e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.ref,
                  style: ApsText.bodyBold.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(dateTime(e.at), style: ApsText.caption),
                if (e.linkedTx != null)
                  Text(
                    'Linked to ${e.linkedTx}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ApsText.caption,
                  ),
                if (!e.serverConfirmed)
                  const Text('Local reference', style: TextStyle(fontSize: 11, color: ApsColors.warn)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 16, color: ApsColors.muted),
            onPressed: () => copyToClipboard(context, e.ref, label: 'Reference ID copied'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? ApsColors.primary : ApsColors.muted;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? ApsColors.infoBg : ApsColors.card,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? ApsColors.primary.withValues(alpha: 0.35) : ApsColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({this.initial});

  final _PeriodFilter? initial;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  _PeriodMode? _mode;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial?.mode;
    _range = widget.initial?.range;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'Select period',
    );
    if (!mounted || picked == null) return;
    setState(() {
      _range = picked;
      _mode = _PeriodMode.custom;
    });
  }

  void _apply() {
    final mode = _mode;
    if (mode == null) {
      Navigator.of(context).pop(const _PeriodResult(null));
      return;
    }
    if (mode == _PeriodMode.custom && _range == null) return;
    Navigator.of(context).pop(_PeriodResult(_PeriodFilter(mode, range: _range)));
  }

  @override
  Widget build(BuildContext context) {
    final canApply = _mode != null && (_mode != _PeriodMode.custom || _range != null);
    return Container(
      decoration: const BoxDecoration(
        color: ApsColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: ApsColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Period', style: ApsText.section),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  'Today',
                  selected: _mode == _PeriodMode.today,
                  onTap: () => setState(() {
                    _mode = _PeriodMode.today;
                    _range = null;
                  }),
                ),
                _Chip(
                  'Yesterday',
                  selected: _mode == _PeriodMode.yesterday,
                  onTap: () => setState(() {
                    _mode = _PeriodMode.yesterday;
                    _range = null;
                  }),
                ),
                _Chip(
                  'Last 7 Days',
                  selected: _mode == _PeriodMode.last7,
                  onTap: () => setState(() {
                    _mode = _PeriodMode.last7;
                    _range = null;
                  }),
                ),
                _Chip(
                  'Custom Date Range',
                  selected: _mode == _PeriodMode.custom,
                  onTap: _pickRange,
                ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: ApsColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ApsColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded, size: 18, color: ApsColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _range == null
                            ? 'Choose a custom date range'
                            : '${DateFormat('d MMM yyyy').format(_range!.start)} - ${DateFormat('d MMM yyyy').format(_range!.end)}',
                        style: _range == null ? ApsText.caption : ApsText.body,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: ApsColors.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(const _PeriodResult(null)),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: canApply ? _apply : null,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TxPickerSheet extends StatelessWidget {
  const _TxPickerSheet({required this.items, this.selected});

  final List<TxItem> items;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      decoration: const BoxDecoration(
        color: ApsColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: ApsColors.border, borderRadius: BorderRadius.circular(999)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(children: [Text('Link to transaction', style: ApsText.section)]),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                itemCount: items.length + 1,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.link_off_rounded, size: 18, color: ApsColors.muted),
                      title: const Text('No linked transaction', style: ApsText.body),
                      trailing: selected == null
                          ? const Icon(Icons.check_rounded, size: 18, color: ApsColors.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(const _PickerResult(null)),
                    );
                  }
                  final tx = items[index - 1];
                  return ListTile(
                    dense: true,
                    leading: GatewayLogo(tx.gateway, size: 30),
                    title: Text(
                      '${tx.gateway?.label ?? 'Payment'} - ${taka(tx.amount)}',
                      style: ApsText.bodyBold.copyWith(fontSize: 13),
                    ),
                    subtitle: Text(
                      'TrxID ${tx.providerTrxId ?? tx.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ApsText.caption,
                    ),
                    trailing: selected == tx.id
                        ? const Icon(Icons.check_rounded, size: 18, color: ApsColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(_PickerResult(tx.id)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
