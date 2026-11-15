import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// The categories that add up to the style score S, in report order.
const scoredCategories = [
  'a.color',
  'a.spacing',
  'a.radius',
  'a.font',
  'a.elevation',
  'b.dialog',
  'c.adaptive',
  'd.string',
];

/// Reported next to S but not part of it: there are no duration tokens yet.
const informationalCategories = ['a.duration', 'a.iconSize'];

/// Font sizes the type scale names; any other literal is off-role.
const fontRoleSizes = <num>{34, 28, 22, 17, 15, 13, 12};

/// Provisional: the 4-pt grid plus 2 and 6. There is no spacing token yet.
const spacingScale = <num>{0, 2, 4, 6, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64};

/// `--h-radius*` in design/web/src/styles/tokens.css, `kHermesRadius` (14) and
/// the overlay radius (28). 0 is square. Any value from [pillRadius] up is the
/// pill and on scale as well.
const radiusScale = <num>{0, 6, 10, 14, 20, 28};

/// The smallest radius that counts as a pill (999, 9999 and the like).
const pillRadius = 999;

bool _onRadiusScale(num v) => radiusScale.contains(v) || v >= pillRadius;

/// The files that implement the shared dialog and sheet helpers.
const dialogHelperFiles = {
  'lib/src/widgets/dialog_presentation.dart',
  'lib/src/widgets/adaptive_sheet.dart',
};

const _dialogFunctions = {
  'showDialog',
  'showCupertinoDialog',
  'showModalBottomSheet',
  'showCupertinoModalPopup',
  'showGeneralDialog',
  'showAdaptiveDialog',
};
const _dialogWidgets = {'AlertDialog', 'CupertinoAlertDialog'};
const _adaptiveWidgets = {
  'Switch',
  'Slider',
  'Checkbox',
  'CircularProgressIndicator',
  'Radio',
  'SwitchListTile',
  'CheckboxListTile',
  'RadioListTile',
};
const _insetsTypes = {'EdgeInsets', 'EdgeInsetsDirectional'};
const _insetsConstructors = {
  'all',
  'symmetric',
  'only',
  'fromLTRB',
  'fromSTEB',
};
const _stringArgs = {
  'label',
  'tooltip',
  'hintText',
  'labelText',
  'helperText',
  'semanticLabel',
  'semanticsLabel',
  'hint',
  'title',
};

const _ruleIds = {
  'a.color': 'style.color',
  'a.spacing': 'style.spacing',
  'a.radius': 'style.radius',
  'a.font': 'style.font',
  'a.elevation': 'style.elevation',
  'b.dialog': 'style.dialog',
  'c.adaptive': 'style.adaptive',
  'd.string': 'style.string',
  'a.duration': 'style.duration',
  'a.iconSize': 'style.iconSize',
};

/// `a.font` with tag `font.offRole` is `style.font.offRole`; the others map
/// one to one.
String ruleIdOf(String category, String? tag) =>
    tag != null ? 'style.$tag' : _ruleIds[category] ?? 'style.$category';

class Finding {
  const Finding(this.path, this.line, this.category, this.snippet, [this.tag]);

  /// A subcount inside the category, e.g. `font.role`.
  final String? tag;

  /// The stable id a repo-wide ratchet keys on, e.g. `style.font.offRole`.
  String get ruleId => ruleIdOf(category, tag);

  final String path;
  final int line;
  final String category;
  final String snippet;

  Map<String, Object?> toJson() => {
    'path': path,
    'line': line,
    'category': category,
    'rule': ruleId,
    'snippet': snippet,
    if (tag != null) 'tag': tag,
  };
}

/// Whether the scan skips [path] (a `/`-separated path from the repo root).
bool isSkipped(String path) =>
    !path.endsWith('.dart') ||
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.startsWith('lib/src/theme/') ||
    path.startsWith('lib/l10n/');

/// `lib/src/<area>/...` is area `<area>`; everything else under lib is `lib`.
String areaOf(String path) {
  final parts = path.split('/');
  if (parts.length > 3 && parts[0] == 'lib' && parts[1] == 'src') {
    return parts[2];
  }
  return 'lib';
}

/// Parses [source] and returns every style finding in it, without any
/// allowlist applied. [path] decides the exemptions (helper files) and is
/// reported as is.
List<Finding> scanSource(String source, {String path = 'lib/x.dart'}) {
  final result = parseString(
    content: source,
    path: path,
    throwIfDiagnostics: false,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  final visitor = _Visitor(path, result.lineInfo, source, result.unit);
  result.unit.accept(visitor);
  return visitor.findings;
}

/// A constructor or function call, whether the parser saw it as a
/// [MethodInvocation] (no `new`/`const`) or an [InstanceCreationExpression].
class _Call {
  _Call(this.node, this.type, this.name, this.args);

  final AstNode node;

  /// `EdgeInsets` in `EdgeInsets.all(8)`, `Color` in `Color(0xFF)`, null for a
  /// plain function call.
  final String? type;

  /// `all` in `EdgeInsets.all(8)`; for an unnamed constructor or a plain
  /// function, the identifier itself (`Color`, `showDialog`).
  final String name;
  final List<Argument> args;

  bool get isUnnamedCtor => type == null;

  /// The class name when this is `Class(...)` or `Class.name(...)`.
  String get className => type ?? name;

  Expression? named(String label) {
    for (final a in args) {
      if (a is NamedArgument && a.name.lexeme == label) {
        return a.argumentExpression;
      }
    }
    return null;
  }

  List<Expression> get positional => args.whereType<Expression>().toList();
}

_Call? _asCall(AstNode node) {
  if (node is MethodInvocation) {
    final target = node.target;
    if (target == null) {
      return _Call(
        node,
        null,
        node.methodName.name,
        node.argumentList.arguments,
      );
    }
    if (target is SimpleIdentifier) {
      return _Call(
        node,
        target.name,
        node.methodName.name,
        node.argumentList.arguments,
      );
    }
    return null;
  }
  if (node is InstanceCreationExpression) {
    final ctor = node.constructorName;
    final type = ctor.type.name.lexeme;
    final named = ctor.name?.name;
    return _Call(
      node,
      named == null ? null : type,
      named ?? type,
      node.argumentList.arguments,
    );
  }
  return null;
}

num? _numLiteral(Expression e) {
  if (e is IntegerLiteral) return e.value;
  if (e is DoubleLiteral) return e.value;
  if (e is PrefixExpression &&
      e.operator.type == TokenType.MINUS &&
      e.operand is Literal) {
    final v = _numLiteral(e.operand);
    return v == null ? null : -v;
  }
  if (e is ParenthesizedExpression) return _numLiteral(e.expression);
  return null;
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this.path, this.lineInfo, this.source, CompilationUnit unit)
    : isHelper = dialogHelperFiles.contains(path),
      importPrefixes = {
        for (final d in unit.directives.whereType<ImportDirective>())
          if (d.prefix != null) d.prefix!.name,
      },
      isWidgetFile = unit.directives.whereType<ImportDirective>().any(
        (d) => const [
          'package:flutter/material.dart',
          'package:flutter/widgets.dart',
          'package:flutter/cupertino.dart',
        ].contains(d.uri.stringValue),
      );

  final String path;
  final LineInfo lineInfo;
  final String source;
  final bool isHelper;

  /// `material` in `import '...' as material;`. A call such as
  /// `material.showDialog(..)` is read as `showDialog(..)`.
  final Set<String> importPrefixes;

  /// Strings count only in files that import the widget layer.
  final bool isWidgetFile;
  final findings = <Finding>[];

  void _add(String category, AstNode node, [String? tag]) {
    final line = lineInfo.getLocation(node.offset).lineNumber;
    var text = source
        .substring(node.offset, node.end)
        .replaceAll(RegExp(r'\s+'), ' ');
    if (text.length > 90) text = '${text.substring(0, 87)}...';
    findings.add(Finding(path, line, category, text, tag));
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 'Colors' && node.identifier.name != 'transparent') {
      _add('a.color', node);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final call = _asCall(node);
    if (call != null) _call(call);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final call = _asCall(node);
    if (call != null) _call(call);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    final label = node.name.lexeme;
    final value = node.argumentExpression;
    final owner = node.parent?.parent;
    final parentCall = owner == null ? null : _asCall(owner);
    switch (label) {
      case 'fontSize':
        final v = _numLiteral(value);
        if (v != null) {
          _add(
            'a.font',
            node,
            fontRoleSizes.contains(v) ? 'font.role' : 'font.offRole',
          );
        }
      case 'elevation':
        final v = _numLiteral(value);
        if (v != null && v != 0) _add('a.elevation', node);
      case 'iconSize':
        if (_numLiteral(value) != null) _add('a.iconSize', node);
      case 'size'
          when const {'Icon', 'AppIcon'}.contains(parentCall?.className):
        if (_numLiteral(value) != null) _add('a.iconSize', node);
      case 'spacing' || 'runSpacing':
        final v = _numLiteral(value);
        if (v != null && !spacingScale.contains(v)) _add('a.spacing', node);
      case 'borderRadius':
        final v = _numLiteral(value);
        if (v != null && !_onRadiusScale(v)) _add('a.radius', node);
      case 'message' when parentCall?.className == 'Tooltip':
        _string(value, node);
      case _ when _stringArgs.contains(label):
        _string(value, node);
    }
    super.visitNamedArgument(node);
  }

  void _call(_Call c) {
    var type = c.type;
    final name = c.name;
    // `prefix.func(..)` parses as a call on a target; a prefixed constructor
    // `prefix.Class(..)` is `type: prefix`.
    if (type != null && importPrefixes.contains(type)) {
      type = null;
    }

    if (type == null && name == 'Color' ||
        type == 'Color' &&
            const {'fromARGB', 'fromRGBO', 'from'}.contains(name)) {
      _add('a.color', c.node);
    }

    if (_insetsTypes.contains(type) && _insetsConstructors.contains(name)) {
      for (final a in c.args) {
        final v = _numLiteral(a.argumentExpression);
        if (v != null && !spacingScale.contains(v)) _add('a.spacing', a);
      }
    }
    if (type == null && name == 'Gap' && c.positional.isNotEmpty) {
      final v = _numLiteral(c.positional.first);
      if (v != null && !spacingScale.contains(v)) _add('a.spacing', c.node);
    }
    final isSizedBox =
        (type == null && name == 'SizedBox') ||
        (type == 'SizedBox' && name == 'square');
    if (isSizedBox &&
        c.named('child') == null &&
        (_isListElement(c.node) || _isSeparator(c.node))) {
      final labels = type == 'SizedBox'
          ? const ['dimension']
          : const ['width', 'height'];
      for (final label in labels) {
        final e = c.named(label);
        final v = e == null ? null : _numLiteral(e);
        if (v != null && !spacingScale.contains(v)) {
          _add('a.spacing', e!.parent!);
        }
      }
    }

    if ((type == 'BorderRadius' && name == 'circular') ||
        (type == 'Radius' && (name == 'circular' || name == 'elliptical'))) {
      for (final a in c.positional) {
        final v = _numLiteral(a);
        if (v != null && !_onRadiusScale(v)) _add('a.radius', c.node);
      }
    }

    if (type == null && name == 'BoxShadow') _add('a.elevation', c.node);

    if (!isHelper) {
      if (type == null && _dialogFunctions.contains(name)) {
        _add('b.dialog', c.node);
      }
      if (type == null && _dialogWidgets.contains(name)) {
        _add('b.dialog', c.node);
      }
    }

    if (type == null && _adaptiveWidgets.contains(name)) {
      _add('c.adaptive', c.node);
    }

    if (isWidgetFile && type == null) {
      if ((name == 'Text' || name == 'SelectableText') &&
          c.positional.isNotEmpty) {
        _string(c.positional.first, c.node);
      }
      if (name == 'TextSpan') {
        final t = c.named('text');
        if (t != null) _string(t, c.node);
      }
    }

    if (type == null && name == 'Duration') {
      final lit = c.args.any(
        (a) => a is NamedArgument && _numLiteral(a.argumentExpression) != null,
      );
      if (lit && _isAnimationDuration(c.node)) _add('a.duration', c.node);
    }
  }

  /// A gap sits among the children of a Row, Column or list; a SizedBox
  /// returned or chosen on its own is a placeholder of some size.
  bool _isListElement(AstNode node) {
    var current = node.parent;
    while (current != null) {
      if (current is ListLiteral) return true;
      if (current is! ConditionalExpression &&
          current is! IfElement &&
          current is! ForElement &&
          current is! ParenthesizedExpression &&
          current is! SpreadElement) {
        return false;
      }
      current = current.parent;
    }
    return false;
  }

  /// The widget a `separatorBuilder:` closure returns is a gap between rows.
  bool _isSeparator(AstNode node) {
    var current = node.parent;
    while (current is ConditionalExpression ||
        current is ParenthesizedExpression) {
      current = current?.parent;
    }
    if (current is ReturnStatement) {
      current = current.parent;
      while (current != null && current is! FunctionBody) {
        current = current.parent;
      }
    }
    if (current is! FunctionBody) return false;
    final fn = current.parent;
    if (fn is! FunctionExpression) return false;
    final arg = fn.parent;
    return arg is NamedArgument && arg.name.lexeme == 'separatorBuilder';
  }

  bool _isAnimationDuration(AstNode node) {
    var named = node.parent;
    while (named is ConditionalExpression || named is ParenthesizedExpression) {
      named = named?.parent;
    }
    if (named is NamedArgument) {
      return named.name.lexeme.toLowerCase().endsWith('duration');
    }
    return false;
  }

  /// Adds [at] when [e] holds user-visible English: a literal (or the
  /// branches of a conditional) with at least two characters and one ASCII
  /// letter outside any interpolation.
  void _string(Expression e, AstNode at) {
    if (!isWidgetFile) return;
    if (_visibleEnglish(e)) _add('d.string', at);
  }

  bool _visibleEnglish(Expression e) {
    if (e is ParenthesizedExpression) return _visibleEnglish(e.expression);
    if (e is ConditionalExpression) {
      return _visibleEnglish(e.thenExpression) ||
          _visibleEnglish(e.elseExpression);
    }
    if (e is StringLiteral) {
      final text = _literalText(e);
      return text.trim().length >= 2 && RegExp('[A-Za-z]').hasMatch(text);
    }
    return false;
  }

  String _literalText(StringLiteral s) {
    if (s is SimpleStringLiteral) return s.value;
    if (s is AdjacentStrings) return s.strings.map(_literalText).join();
    if (s is StringInterpolation) {
      return s.elements
          .whereType<InterpolationString>()
          .map((e) => e.value)
          .join();
    }
    return '';
  }
}
