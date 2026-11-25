/// `arch.gateway-request-timeout`: a `.timeout(` wrapped around a gateway RPC
/// request future.
///
/// `Future.timeout` abandons the caller and leaves the request, its entry in
/// the client's pending table and its span open until the socket ends (the
/// slow `session.resume` and `session.active_list` calls #1382 fixed). The
/// client's own `timeout:` parameter settles the request and ends its span.
///
/// The scan reads the analyzer's unresolved syntax tree, so it knows names,
/// not types: see the `architecture-guards` skill for what it misses.
library;

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'source_scan.dart';

/// The methods of `GatewayRpcClient`, `GatewayRequester` and the transport
/// that send a request whatever their arguments are.
const _requestMethods = {
  'requestWithin',
  'requestGuarded',
  'requestKeepingConnection',
  'requestKeepingConnectionOnClient',
  'requestOn',
};

/// The private helpers of the gateway transport that send a request.
const _transportHelpers = {'_call', '_actOnAgent'};

const _gatewayDir = 'lib/src/chat/gateway/';

/// A Hermes gateway method name: `session.resume`, `approval.pending`.
final _methodName = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$');

/// Whether [node] is a call that sends a gateway request. `request` is also a
/// name other APIs use (a permission, an open-request queue), so it counts
/// only with a gateway method name as its first argument, as a literal or as
/// the identifier `method` a pass-through takes.
bool _sendsRequest(MethodInvocation node, {required bool inGatewayDir}) {
  final name = node.methodName.name;
  if (_requestMethods.contains(name)) return true;
  if (inGatewayDir && _transportHelpers.contains(name)) return true;
  if (name != 'request') return false;
  final args = node.argumentList.arguments;
  if (args.isEmpty) return false;
  return switch (args.first) {
    SimpleStringLiteral(:final value) => _methodName.hasMatch(value),
    SimpleIdentifier(:final name) => name == 'method',
    _ => false,
  };
}

class _Requests extends RecursiveAstVisitor<void> {
  _Requests({required this.inGatewayDir});
  final bool inGatewayDir;
  var found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_sendsRequest(node, inGatewayDir: inGatewayDir)) found = true;
    super.visitMethodInvocation(node);
  }
}

bool _containsRequest(AstNode node, {required bool inGatewayDir}) {
  final visitor = _Requests(inGatewayDir: inGatewayDir);
  node.accept(visitor);
  return visitor.found;
}

/// A local variable: its initializer and the block it is visible in.
typedef _Declaration = ({int offset, Expression init, AstNode scope});

/// Local variables of one member, by name.
class _Declarations extends RecursiveAstVisitor<void> {
  final byName = <String, List<_Declaration>>{};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final init = node.initializer;
    final scope = node.thisOrAncestorMatching(
      (n) => n is Block || n is FunctionBody || n is ForStatement,
    );
    if (init != null && scope != null) {
      (byName[node.name.lexeme] ??= []).add((
        offset: node.offset,
        init: init,
        scope: scope,
      ));
    }
    super.visitVariableDeclaration(node);
  }
}

/// The initializer of the declaration of [name] that [use] sees: the closest
/// one before it whose block holds it.
Expression? _visibleInitializer(
  Map<String, List<_Declaration>> byName,
  String name,
  AstNode use,
) {
  _Declaration? best;
  for (final d in byName[name] ?? const <_Declaration>[]) {
    final holdsUse = d.scope.offset <= use.offset && use.end <= d.scope.end;
    if (holdsUse && d.offset < use.offset) {
      if (best == null || d.offset > best.offset) best = d;
    }
  }
  return best?.init;
}

class _Timeouts extends RecursiveAstVisitor<void> {
  final calls = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'timeout' && node.realTarget != null) {
      calls.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// The `.timeout(` calls of [file] whose receiver is a gateway request: a
/// request call inside the receiver expression, or a local variable of the
/// same member that was initialised from one.
List<Hit> gatewayRequestTimeoutHitsIn(SourceFile file) {
  final unit = parseString(
    content: file.raw,
    path: file.path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  final timeouts = _Timeouts();
  unit.accept(timeouts);
  final inGatewayDir = file.path.startsWith(_gatewayDir);
  final hits = <Hit>[];
  for (final call in timeouts.calls) {
    final target = call.realTarget!;
    var flagged = _containsRequest(target, inGatewayDir: inGatewayDir);
    if (!flagged && target is SimpleIdentifier) {
      final member = call.thisOrAncestorMatching(
        (n) => n is MethodDeclaration || n is FunctionDeclaration,
      );
      if (member != null) {
        final declarations = _Declarations();
        member.accept(declarations);
        final init = _visibleInitializer(
          declarations.byName,
          target.name,
          call,
        );
        flagged =
            init != null && _containsRequest(init, inGatewayDir: inGatewayDir);
      }
    }
    if (flagged) {
      final line = file.lineOf(call.methodName.offset);
      hits.add(Hit(file.path, line, file.lineText(line)));
    }
  }
  return hits;
}

/// Every hit under `lib/`.
List<Hit> gatewayRequestTimeoutHits() => [
  for (final file in dartFiles('lib')) ...gatewayRequestTimeoutHitsIn(file),
];
