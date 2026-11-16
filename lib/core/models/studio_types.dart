import 'dart:math' as math;

enum RecordSource { seed, member }

enum RecipeKind { glaze, slip, engobe, wash }

enum Atmosphere { oxidation, reduction, neutral, wood, soda, salt }

enum Surface { glossy, satin, matte, dry, crystalline }

enum IngredientRole { base, colorant, opacifier, additive }

enum FiringStatus { scheduled, loading, firing, cooling, unloaded }

enum ConeBand { low, mid, high }

extension RecipeKindLabel on RecipeKind {
  String get label => switch (this) {
        RecipeKind.glaze => 'Glaze',
        RecipeKind.slip => 'Slip',
        RecipeKind.engobe => 'Engobe',
        RecipeKind.wash => 'Wash',
      };

  String get plural => switch (this) {
        RecipeKind.glaze => 'Glazes',
        RecipeKind.slip => 'Slips',
        RecipeKind.engobe => 'Engobes',
        RecipeKind.wash => 'Washes',
      };
}

extension AtmosphereLabel on Atmosphere {
  String get label => switch (this) {
        Atmosphere.oxidation => 'Oxidation',
        Atmosphere.reduction => 'Reduction',
        Atmosphere.neutral => 'Neutral',
        Atmosphere.wood => 'Wood',
        Atmosphere.soda => 'Soda',
        Atmosphere.salt => 'Salt',
      };
}

extension SurfaceLabel on Surface {
  String get label => switch (this) {
        Surface.glossy => 'Glossy',
        Surface.satin => 'Satin',
        Surface.matte => 'Matte',
        Surface.dry => 'Dry',
        Surface.crystalline => 'Crystalline',
      };
}

extension IngredientRoleLabel on IngredientRole {
  String get label => switch (this) {
        IngredientRole.base => 'Base',
        IngredientRole.colorant => 'Colorant',
        IngredientRole.opacifier => 'Opacifier',
        IngredientRole.additive => 'Additive',
      };
}

extension FiringStatusLabel on FiringStatus {
  String get label => switch (this) {
        FiringStatus.scheduled => 'Scheduled',
        FiringStatus.loading => 'Loading',
        FiringStatus.firing => 'Firing',
        FiringStatus.cooling => 'Cooling',
        FiringStatus.unloaded => 'Unloaded',
      };

  bool get isActive => switch (this) {
        FiringStatus.loading || FiringStatus.firing || FiringStatus.cooling => true,
        FiringStatus.scheduled || FiringStatus.unloaded => false,
      };
}

extension ConeBandLabel on ConeBand {
  String get label => switch (this) {
        ConeBand.low => 'Low',
        ConeBand.mid => 'Midfire',
        ConeBand.high => 'High fire',
      };
}

const coneLabels = [
  '022',
  '06',
  '04',
  '02',
  '1',
  '2',
  '4',
  '5',
  '6',
  '8',
  '9',
  '10',
  '11',
  '12',
];

const kilnNames = ['Skutt 1227', 'Bailey gas', 'Train wood kiln'];

const studioName = 'East River Clay';

T enumByName<T extends Enum>(List<T> values, Object? raw, String field) {
  if (raw is! String) throw FormatException('Expected $field.');
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Unknown $field: $raw');
}

double coneValue(String label) {
  final trimmed = label.trim();
  if (!coneLabels.contains(trimmed)) {
    throw FormatException('Unknown cone $label.');
  }
  if (trimmed.startsWith('0') && trimmed.length > 1) {
    return -double.parse(trimmed.substring(1));
  }
  return double.parse(trimmed);
}

extension ConeBandRange on ConeBand {
  bool overlaps(String min, String max) {
    final low = math.min(coneValue(min), coneValue(max));
    final high = math.max(coneValue(min), coneValue(max));
    final (start, end) = switch (this) {
      ConeBand.low => (-22.0, 1.0),
      ConeBand.mid => (2.0, 6.0),
      ConeBand.high => (7.0, 20.0),
    };
    return low <= end && high >= start;
  }
}

String jsonText(Map<String, dynamic> json, String key, {bool allowEmpty = false}) {
  final value = json[key];
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw FormatException('Expected $key.');
  }
  return value.trim();
}

double jsonDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('Expected $key.');
  return value.toDouble();
}

int jsonInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('Expected $key.');
  return value.toInt();
}

bool jsonBool(Map<String, dynamic> json, String key) => json[key] == true;
