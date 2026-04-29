import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RemoteTextInputDialog extends StatefulWidget {
  final String title;
  final String value;
  final String? labelText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;

  const RemoteTextInputDialog({
    super.key,
    required this.title,
    required this.value,
    this.labelText,
    this.hintText,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  State<RemoteTextInputDialog> createState() => _RemoteTextInputDialogState();
}

class _RemoteTextInputDialogState extends State<RemoteTextInputDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _applyRemoteValue(String value) {
    _textController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _formKey.currentState?.validate();
  }

  void _submit() {
    if (_formKey.currentState?.validate() == false) {
      return;
    }
    Navigator.of(context).pop<String>(_textController.text);
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: widget.title,
      actions: [
        TextButton(
          onPressed: _submit,
          child: Text(appLocalizations.submit),
        ),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: widget.autovalidateMode,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                keyboardType: TextInputType.url,
                maxLines: 5,
                minLines: 1,
                controller: _textController,
                onFieldSubmitted: (_) {
                  _submit();
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: widget.hintText,
                  labelText: widget.labelText,
                ),
                validator: widget.validator,
              ),
              const SizedBox(height: 16),
              RemoteInputPanel(
                title: widget.title,
                initialValue: widget.value,
                onReceived: _applyRemoteValue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RemoteInputSuffixButton extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final ValueChanged<String>? onReceived;

  const RemoteInputSuffixButton({
    super.key,
    required this.controller,
    required this.title,
    this.onReceived,
  });

  void _applyValue(String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    onReceived?.call(value);
  }

  Future<void> _showRemoteInput(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) {
        return RemoteInputReceiveDialog(
          title: title,
          initialValue: controller.text,
          onReceived: _applyValue,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _copy(context).openRemoteInput,
      icon: const Icon(Icons.qr_code_2),
      onPressed: () {
        _showRemoteInput(context);
      },
    );
  }
}

class RemoteInputReceiveDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final ValueChanged<String> onReceived;

  const RemoteInputReceiveDialog({
    super.key,
    required this.title,
    required this.initialValue,
    required this.onReceived,
  });

  @override
  State<RemoteInputReceiveDialog> createState() =>
      _RemoteInputReceiveDialogState();
}

class _RemoteInputReceiveDialogState extends State<RemoteInputReceiveDialog> {
  String? _receivedValue;

  void _handleReceived(String value) {
    setState(() {
      _receivedValue = value;
    });
    widget.onReceived(value);
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: widget.title,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RemoteInputPanel(
              title: widget.title,
              initialValue: widget.initialValue,
              onReceived: _handleReceived,
            ),
            if (_receivedValue != null) ...[
              const SizedBox(height: 12),
              Text(
                _copy(context).received,
                style: TextStyle(color: context.colorScheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RemoteInputPanel extends StatefulWidget {
  final String title;
  final String initialValue;
  final ValueChanged<String> onReceived;

  const RemoteInputPanel({
    super.key,
    required this.title,
    required this.initialValue,
    required this.onReceived,
  });

  @override
  State<RemoteInputPanel> createState() => _RemoteInputPanelState();
}

class _RemoteInputPanelState extends State<RemoteInputPanel> {
  late final Future<RemoteInputSession> _sessionFuture;
  RemoteInputSession? _session;
  String? _lastValue;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _createSession();
  }

  @override
  void dispose() {
    _disposed = true;
    _session?.valueNotifier.removeListener(_handleRemoteValue);
    _session?.dispose();
    super.dispose();
  }

  Future<RemoteInputSession> _createSession() async {
    final session = await remoteInputServer.createSession(
      title: widget.title,
      initialValue: widget.initialValue,
    );
    if (_disposed) {
      session.dispose();
      return session;
    }
    _session = session;
    session.valueNotifier.addListener(_handleRemoteValue);
    return session;
  }

  void _handleRemoteValue() {
    final value = _session?.valueNotifier.value;
    if (value == null || value == _lastValue) {
      return;
    }
    _lastValue = value;
    widget.onReceived(value);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy(context);
    return FutureBuilder<RemoteInputSession>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            copy.startFailed,
            style: TextStyle(color: context.colorScheme.error),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.data!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: QrImageView(
                  data: session.url,
                  version: QrVersions.auto,
                  size: 192,
                  gapless: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              copy.scanTip,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              session.url,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall,
            ),
            if (_lastValue != null) ...[
              const SizedBox(height: 8),
              Text(
                copy.received,
                style: TextStyle(color: context.colorScheme.primary),
              ),
            ],
          ],
        );
      },
    );
  }
}

_RemoteInputCopy _copy(BuildContext context) {
  final languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'zh') {
    return const _RemoteInputCopy(
      openRemoteInput: '扫码输入',
      scanTip: '用手机扫描二维码，在手机上输入后会自动回填到电视输入框。',
      received: '已收到手机输入',
      startFailed: '无法启动局域网输入服务',
    );
  }
  return const _RemoteInputCopy(
    openRemoteInput: 'Remote input',
    scanTip:
        'Scan with your phone. Text submitted on your phone will fill this field.',
    received: 'Received from phone',
    startFailed: 'Unable to start remote input service',
  );
}

class _RemoteInputCopy {
  final String openRemoteInput;
  final String scanTip;
  final String received;
  final String startFailed;

  const _RemoteInputCopy({
    required this.openRemoteInput,
    required this.scanTip,
    required this.received,
    required this.startFailed,
  });
}
