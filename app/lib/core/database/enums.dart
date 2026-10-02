import 'package:drift/drift.dart';

/// DB에는 [value] 문자열로 저장한다 (기획서 7.1). 이름을 바꿔도 저장값이 깨지지 않게 enum name을 쓰지 않는다.
enum Gender {
  male('male'),
  female('female'),
  unspecified('unspecified');

  const Gender(this.value);
  final String value;
}

/// 컵 종류 (기획서 5.2). 기록은 항상 ml로 저장되며 컵은 프리셋의 겉모습이다.
enum CupType {
  paper('paper'),
  mug('mug'),
  tumbler('tumbler'),
  other('other');

  const CupType(this.value);
  final String value;
}

/// 기록 방식 (기획서 7.1 intake_log.source).
enum IntakeSource {
  quick('quick'),
  custom('custom'),
  bulk('bulk');

  const IntakeSource(this.value);
  final String value;
}

/// 꾸미기 카테고리 (기획서 6장 S3 슬롯 구조).
enum DecorationCategory {
  background('background'),
  pot('pot'),
  eyes('eyes'),
  nose('nose'),
  mouth('mouth'),
  cheek('cheek'),
  headwear('headwear');

  const DecorationCategory(this.value);
  final String value;
}

/// 아이템 해금 조건 유형 (기획서 7.1 decoration_item.unlock_type).
enum UnlockType {
  defaultGrant('default'),
  streak('streak'),
  totalDays('total_days'),
  purchase('purchase');

  const UnlockType(this.value);
  final String value;
}

class _ValueConverter<T extends Enum> extends TypeConverter<T, String> {
  const _ValueConverter(this._values, this._valueOf);

  final List<T> _values;
  final String Function(T) _valueOf;

  @override
  T fromSql(String fromDb) =>
      _values.firstWhere((e) => _valueOf(e) == fromDb);

  @override
  String toSql(T value) => _valueOf(value);
}

const genderConverter =
    _ValueConverter<Gender>(Gender.values, _genderValue);
const cupTypeConverter =
    _ValueConverter<CupType>(CupType.values, _cupTypeValue);
const intakeSourceConverter =
    _ValueConverter<IntakeSource>(IntakeSource.values, _intakeSourceValue);
const decorationCategoryConverter = _ValueConverter<DecorationCategory>(
    DecorationCategory.values, _decorationCategoryValue);
const unlockTypeConverter =
    _ValueConverter<UnlockType>(UnlockType.values, _unlockTypeValue);

String _genderValue(Gender e) => e.value;
String _cupTypeValue(CupType e) => e.value;
String _intakeSourceValue(IntakeSource e) => e.value;
String _decorationCategoryValue(DecorationCategory e) => e.value;
String _unlockTypeValue(UnlockType e) => e.value;
