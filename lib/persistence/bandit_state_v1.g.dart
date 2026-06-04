// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bandit_state_v1.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBanditStateV1Collection on Isar {
  IsarCollection<BanditStateV1> get banditStateV1 => this.collection();
}

const BanditStateV1Schema = CollectionSchema(
  name: r'BanditStateV1',
  id: 1753627432560743480,
  properties: {
    r'alpha': PropertySchema(id: 0, name: r'alpha', type: IsarType.double),
    r'beta': PropertySchema(id: 1, name: r'beta', type: IsarType.double),
    r'buttonId': PropertySchema(
      id: 2,
      name: r'buttonId',
      type: IsarType.string,
    ),
    r'observationCount': PropertySchema(
      id: 3,
      name: r'observationCount',
      type: IsarType.long,
    ),
    r'stateKey': PropertySchema(
      id: 4,
      name: r'stateKey',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 5,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _banditStateV1EstimateSize,
  serialize: _banditStateV1Serialize,
  deserialize: _banditStateV1Deserialize,
  deserializeProp: _banditStateV1DeserializeProp,
  idName: r'id',
  indexes: {
    r'stateKey_buttonId': IndexSchema(
      id: 9138998745766739254,
      name: r'stateKey_buttonId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'stateKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'buttonId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _banditStateV1GetId,
  getLinks: _banditStateV1GetLinks,
  attach: _banditStateV1Attach,
  version: '3.3.0',
);

int _banditStateV1EstimateSize(
  BanditStateV1 object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.buttonId.length * 3;
  bytesCount += 3 + object.stateKey.length * 3;
  return bytesCount;
}

void _banditStateV1Serialize(
  BanditStateV1 object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.alpha);
  writer.writeDouble(offsets[1], object.beta);
  writer.writeString(offsets[2], object.buttonId);
  writer.writeLong(offsets[3], object.observationCount);
  writer.writeString(offsets[4], object.stateKey);
  writer.writeDateTime(offsets[5], object.updatedAt);
}

BanditStateV1 _banditStateV1Deserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BanditStateV1();
  object.alpha = reader.readDouble(offsets[0]);
  object.beta = reader.readDouble(offsets[1]);
  object.buttonId = reader.readString(offsets[2]);
  object.id = id;
  object.observationCount = reader.readLong(offsets[3]);
  object.stateKey = reader.readString(offsets[4]);
  object.updatedAt = reader.readDateTime(offsets[5]);
  return object;
}

P _banditStateV1DeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _banditStateV1GetId(BanditStateV1 object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _banditStateV1GetLinks(BanditStateV1 object) {
  return [];
}

void _banditStateV1Attach(
  IsarCollection<dynamic> col,
  Id id,
  BanditStateV1 object,
) {
  object.id = id;
}

extension BanditStateV1ByIndex on IsarCollection<BanditStateV1> {
  Future<BanditStateV1?> getByStateKeyButtonId(
    String stateKey,
    String buttonId,
  ) {
    return getByIndex(r'stateKey_buttonId', [stateKey, buttonId]);
  }

  BanditStateV1? getByStateKeyButtonIdSync(String stateKey, String buttonId) {
    return getByIndexSync(r'stateKey_buttonId', [stateKey, buttonId]);
  }

  Future<bool> deleteByStateKeyButtonId(String stateKey, String buttonId) {
    return deleteByIndex(r'stateKey_buttonId', [stateKey, buttonId]);
  }

  bool deleteByStateKeyButtonIdSync(String stateKey, String buttonId) {
    return deleteByIndexSync(r'stateKey_buttonId', [stateKey, buttonId]);
  }

  Future<List<BanditStateV1?>> getAllByStateKeyButtonId(
    List<String> stateKeyValues,
    List<String> buttonIdValues,
  ) {
    final len = stateKeyValues.length;
    assert(
      buttonIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([stateKeyValues[i], buttonIdValues[i]]);
    }

    return getAllByIndex(r'stateKey_buttonId', values);
  }

  List<BanditStateV1?> getAllByStateKeyButtonIdSync(
    List<String> stateKeyValues,
    List<String> buttonIdValues,
  ) {
    final len = stateKeyValues.length;
    assert(
      buttonIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([stateKeyValues[i], buttonIdValues[i]]);
    }

    return getAllByIndexSync(r'stateKey_buttonId', values);
  }

  Future<int> deleteAllByStateKeyButtonId(
    List<String> stateKeyValues,
    List<String> buttonIdValues,
  ) {
    final len = stateKeyValues.length;
    assert(
      buttonIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([stateKeyValues[i], buttonIdValues[i]]);
    }

    return deleteAllByIndex(r'stateKey_buttonId', values);
  }

  int deleteAllByStateKeyButtonIdSync(
    List<String> stateKeyValues,
    List<String> buttonIdValues,
  ) {
    final len = stateKeyValues.length;
    assert(
      buttonIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([stateKeyValues[i], buttonIdValues[i]]);
    }

    return deleteAllByIndexSync(r'stateKey_buttonId', values);
  }

  Future<Id> putByStateKeyButtonId(BanditStateV1 object) {
    return putByIndex(r'stateKey_buttonId', object);
  }

  Id putByStateKeyButtonIdSync(BanditStateV1 object, {bool saveLinks = true}) {
    return putByIndexSync(r'stateKey_buttonId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByStateKeyButtonId(List<BanditStateV1> objects) {
    return putAllByIndex(r'stateKey_buttonId', objects);
  }

  List<Id> putAllByStateKeyButtonIdSync(
    List<BanditStateV1> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'stateKey_buttonId',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension BanditStateV1QueryWhereSort
    on QueryBuilder<BanditStateV1, BanditStateV1, QWhere> {
  QueryBuilder<BanditStateV1, BanditStateV1, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension BanditStateV1QueryWhere
    on QueryBuilder<BanditStateV1, BanditStateV1, QWhereClause> {
  QueryBuilder<BanditStateV1, BanditStateV1, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterWhereClause>
  stateKeyEqualToAnyButtonId(String stateKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'stateKey_buttonId',
          value: [stateKey],
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterWhereClause>
  stateKeyNotEqualToAnyButtonId(String stateKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'stateKey_buttonId',
                lower: [],
                upper: [stateKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'stateKey_buttonId',
                lower: [stateKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'stateKey_buttonId',
                lower: [stateKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'stateKey_buttonId',
                lower: [],
                upper: [stateKey],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterWhereClause>
  stateKeyButtonIdEqualTo(String stateKey, String buttonId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'stateKey_buttonId',
          value: [stateKey, buttonId],
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterWhereClause>
  stateKeyEqualToButtonIdNotEqualTo(String stateKey, String buttonId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'stateKey_buttonId',
                lower: [stateKey],
                upper: [stateKey, buttonId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'stateKey_buttonId',
                lower: [stateKey, buttonId],
                includeLower: false,
                upper: [stateKey],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'stateKey_buttonId',
                lower: [stateKey, buttonId],
                includeLower: false,
                upper: [stateKey],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'stateKey_buttonId',
                lower: [stateKey],
                upper: [stateKey, buttonId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension BanditStateV1QueryFilter
    on QueryBuilder<BanditStateV1, BanditStateV1, QFilterCondition> {
  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  alphaEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'alpha',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  alphaGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'alpha',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  alphaLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'alpha',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  alphaBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'alpha',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition> betaEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'beta',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  betaGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'beta',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  betaLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'beta',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition> betaBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'beta',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  buttonIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'buttonId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  buttonIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'buttonId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  buttonIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'buttonId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  buttonIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'buttonId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  buttonIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'buttonId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  buttonIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'buttonId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  buttonIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'buttonId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  buttonIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'buttonId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  buttonIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'buttonId', value: ''),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  buttonIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'buttonId', value: ''),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  observationCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'observationCount', value: value),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  observationCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'observationCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  observationCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'observationCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  observationCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'observationCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  stateKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  stateKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  stateKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  stateKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'stateKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  stateKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  stateKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  stateKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'stateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  stateKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'stateKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  stateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'stateKey', value: ''),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  stateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'stateKey', value: ''),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  updatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterFilterCondition>
  updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension BanditStateV1QueryObject
    on QueryBuilder<BanditStateV1, BanditStateV1, QFilterCondition> {}

extension BanditStateV1QueryLinks
    on QueryBuilder<BanditStateV1, BanditStateV1, QFilterCondition> {}

extension BanditStateV1QuerySortBy
    on QueryBuilder<BanditStateV1, BanditStateV1, QSortBy> {
  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> sortByAlpha() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alpha', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> sortByAlphaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alpha', Sort.desc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> sortByBeta() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beta', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> sortByBetaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beta', Sort.desc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> sortByButtonId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buttonId', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy>
  sortByButtonIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buttonId', Sort.desc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy>
  sortByObservationCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observationCount', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy>
  sortByObservationCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observationCount', Sort.desc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> sortByStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy>
  sortByStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.desc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension BanditStateV1QuerySortThenBy
    on QueryBuilder<BanditStateV1, BanditStateV1, QSortThenBy> {
  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> thenByAlpha() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alpha', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> thenByAlphaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alpha', Sort.desc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> thenByBeta() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beta', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> thenByBetaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beta', Sort.desc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> thenByButtonId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buttonId', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy>
  thenByButtonIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'buttonId', Sort.desc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy>
  thenByObservationCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observationCount', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy>
  thenByObservationCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'observationCount', Sort.desc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> thenByStateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy>
  thenByStateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stateKey', Sort.desc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension BanditStateV1QueryWhereDistinct
    on QueryBuilder<BanditStateV1, BanditStateV1, QDistinct> {
  QueryBuilder<BanditStateV1, BanditStateV1, QDistinct> distinctByAlpha() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'alpha');
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QDistinct> distinctByBeta() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'beta');
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QDistinct> distinctByButtonId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'buttonId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QDistinct>
  distinctByObservationCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'observationCount');
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QDistinct> distinctByStateKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stateKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BanditStateV1, BanditStateV1, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension BanditStateV1QueryProperty
    on QueryBuilder<BanditStateV1, BanditStateV1, QQueryProperty> {
  QueryBuilder<BanditStateV1, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BanditStateV1, double, QQueryOperations> alphaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'alpha');
    });
  }

  QueryBuilder<BanditStateV1, double, QQueryOperations> betaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'beta');
    });
  }

  QueryBuilder<BanditStateV1, String, QQueryOperations> buttonIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'buttonId');
    });
  }

  QueryBuilder<BanditStateV1, int, QQueryOperations>
  observationCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'observationCount');
    });
  }

  QueryBuilder<BanditStateV1, String, QQueryOperations> stateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stateKey');
    });
  }

  QueryBuilder<BanditStateV1, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
