/// The scan behind `arch.chat-catch-all-reports` (`architecture_guards_test.dart`).
///
/// Reads the analyzer's unresolved syntax tree of a file for a `catch` that can
/// catch an `Error` (no `on` type, `on Object`, `on Error`, `on dynamic`) and
/// does not hand the error on. A swallowed `Error` is a bug (a `StateError`, a
/// `TypeError`, a null check) that a catch-all turned into a quiet fallback.
library;

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'source_scan.dart';

/// A catch-all that swallows, and the `path#Class.member` it is in.
typedef CatchAllFinding = ({Hit hit, String owner});

/// Types an `on` clause can name and still catch an `Error`.
const _catchAllTypes = {'Object', 'Error', 'dynamic'};

/// Calls (with no receiver) that hand an error to the crash reporter.
const _reporters = {'reportBug', 'reportChatBug', 'reportUnreadablePrefs'};

/// Calls that take the error itself as an argument and carry it on.
const _sinkCalls = {
  'completeError',
  'addError',
  'onError',
  'onFailure',
  'handleError',
};

/// Named arguments that carry the error (`copyWith(error: e)`).
const _namedSlots = {'error', 'exception', 'cause'};

/// A field or variable that holds an error for the screen.
final _errorSlot = RegExp(r'error|failure|exception', caseSensitive: false);

/// Whether [clause] can catch an `Error`.
bool catchesErrors(CatchClause clause) {
  final type = clause.exceptionType;
  if (type == null) return true;
  return type is NamedType && _catchAllTypes.contains(type.name.lexeme);
}

/// The catch-alls of [file] that neither rethrow, nor report, nor hand the
/// error on.
///
/// Handled means a real sink directly in the clause's body (not in a nested
/// `catch`, not in a function literal, which may never run or shadow the
/// error): a `rethrow`, a `throw` or `Error.throwWithStackTrace`;
/// `reportBug` or `reportUnreadablePrefs` (no receiver) or
/// `FlutterError.reportError` called with the error; the error itself passed
/// to `completeError`, `addError`, `Future.error`, `onError`, `onFailure` or
/// `handleError`, or as an `error:`, `exception:` or `cause:` argument;
/// assigned to a field or variable whose name holds `error`, `failure` or
/// `exception`; or returned as is. A classifier (`kindOf(e)`), a predicate
/// (`if (isCancel(e)) return;`), an interpolation, a member read
/// (`e.runtimeType`) and `debugPrint(e)` are not sinks.
List<CatchAllFinding> catchAllFindingsIn(SourceFile file) {
  final unit = parseString(
    content: file.raw,
    path: file.path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  final found = <CatchAllFinding>[];
  unit.accept(
    _Catches((clause) {
      if (!catchesErrors(clause) || _handlesError(clause)) return;
      final line = file.lineOf(clause.offset);
      found.add((
        hit: Hit(file.path, line, file.lineText(line)),
        owner: '${file.path}#${_ownerOf(clause)}',
      ));
    }),
  );
  return found;
}

class _Catches extends RecursiveAstVisitor<void> {
  _Catches(this.onClause);
  final void Function(CatchClause) onClause;

  @override
  void visitCatchClause(CatchClause node) {
    onClause(node);
    super.visitCatchClause(node);
  }
}

/// `Class.member` of the outermost declaration around [node], or the
/// top-level name.
String _ownerOf(AstNode node) {
  String? member;
  String? type;
  for (AstNode? n = node; n != null; n = n.parent) {
    if (n is MethodDeclaration) {
      member = n.name.lexeme;
    } else if (n is ConstructorDeclaration) {
      member = n.name?.lexeme ?? 'new';
    } else if (n is FunctionDeclaration && n.parent is CompilationUnit) {
      member = n.name.lexeme;
    } else if (n is FieldDeclaration) {
      member = n.fields.variables.first.name.lexeme;
    } else if (n is ClassDeclaration) {
      type = n.namePart.typeName.lexeme;
    } else if (n is MixinDeclaration) {
      type = n.name.lexeme;
    } else if (n is ExtensionDeclaration) {
      type = n.name?.lexeme ?? 'extension';
    } else if (n is EnumDeclaration) {
      type = n.namePart.typeName.lexeme;
    }
  }
  if (type != null && member != null) return '$type.$member';
  return member ?? type ?? 'top-level';
}

bool _handlesError(CatchClause clause) {
  final finder = _SinkFinder(clause.exceptionParameter?.name.lexeme);
  clause.body.accept(finder);
  return finder.handled;
}

/// Walks a catch body for a real sink. It does not enter a nested `catch`
/// (judged on its own) or a function literal (it may never run, and its own
/// parameter may shadow the error).
class _SinkFinder extends RecursiveAstVisitor<void> {
  _SinkFinder(this.errorName);
  final String? errorName;
  bool handled = false;

  @override
  void visitCatchClause(CatchClause node) {}

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitRethrowExpression(RethrowExpression node) => handled = true;

  @override
  void visitThrowExpression(ThrowExpression node) => handled = true;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final target = node.target;
    final args = node.argumentList.arguments;
    final error = errorName;
    if (name == 'throwWithStackTrace') {
      handled = true;
    } else if (error != null) {
      if (_reporters.contains(name) && target == null) {
        handled =
            handled || args.any((a) => _mentions(a.argumentExpression, error));
      } else if (name == 'reportError' &&
          target is SimpleIdentifier &&
          target.name == 'FlutterError') {
        handled =
            handled || args.any((a) => _mentions(a.argumentExpression, error));
      } else if (_sinkCalls.contains(name) ||
          (name == 'error' && _isNamed(target, 'Future')) ||
          (name == 'call' && _isErrorCallback(target))) {
        handled =
            handled || args.any((a) => _isBare(a.argumentExpression, error));
      }
      handled =
          handled ||
          args.any((a) => a is NamedArgument && _namedErrorSlot(a, error));
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final error = errorName;
    if (error != null && _isBare(node.rightHandSide, error)) {
      final left = node.leftHandSide;
      final slot = switch (left) {
        SimpleIdentifier() => left.name,
        PrefixedIdentifier() => left.identifier.name,
        PropertyAccess() => left.propertyName.name,
        _ => '',
      };
      if (_errorSlot.hasMatch(slot)) handled = true;
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    final error = errorName;
    final value = node.expression;
    if (error != null && value != null && _isBare(value, error)) {
      handled = true;
    }
    super.visitReturnStatement(node);
  }
}

/// `reader.failure?.call(e)`, `onError.call(e)`: a callback named for errors.
bool _isErrorCallback(Expression? target) {
  final name = switch (target) {
    SimpleIdentifier() => target.name,
    PrefixedIdentifier() => target.identifier.name,
    PropertyAccess() => target.propertyName.name,
    _ => '',
  };
  return _errorSlot.hasMatch(name);
}

bool _isNamed(Expression? target, String name) =>
    target is SimpleIdentifier && target.name == name;

/// `error: e`, `exception: e`, `cause: e`.
bool _namedErrorSlot(NamedArgument argument, String error) =>
    _namedSlots.contains(argument.name.lexeme) &&
    _isBare(argument.argumentExpression, error);

/// Whether [expression] is the error variable itself, through `(e)`,
/// `e as Object`, `e!` and either branch of `cond ? e : other`.
bool _isBare(Expression expression, String error) {
  var node = expression;
  while (true) {
    if (node is ConditionalExpression) {
      return _isBare(node.thenExpression, error) ||
          _isBare(node.elseExpression, error);
    }
    if (node is ParenthesizedExpression) {
      node = node.expression;
    } else if (node is AsExpression) {
      node = node.expression;
    } else if (node is PostfixExpression) {
      node = node.operand;
    } else {
      break;
    }
  }
  return node is SimpleIdentifier && node.name == error;
}

/// Whether the error variable occurs in [node] outside a string interpolation
/// and a function literal.
bool _mentions(AstNode node, String error) {
  final finder = _Mention(error);
  node.accept(finder);
  return finder.found;
}

class _Mention extends RecursiveAstVisitor<void> {
  _Mention(this.error);
  final String error;
  bool found = false;

  @override
  void visitInterpolationExpression(InterpolationExpression node) {}

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == error && !_isMemberRead(node)) found = true;
  }
}

/// `e.runtimeType`, `e.message`, `e?.x`: a read of a member, not the error.
bool _isMemberRead(SimpleIdentifier node) {
  final parent = node.parent;
  return (parent is PrefixedIdentifier && parent.prefix == node) ||
      (parent is PropertyAccess && parent.target == node) ||
      (parent is MethodInvocation && parent.target == node);
}
