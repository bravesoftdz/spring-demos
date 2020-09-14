unit Delphi.Functional;

interface

uses
  Classes,
  Diagnostics,
  Generics.Collections,
  Generics.Defaults,
  Rtti,
  SyncObjs,
  SysUtils,
  TimeSpan,
  Types,
  TypInfo,
  Variants;

type
  Maybe = record
  private
    const HasValue = 'True';
    type Null = interface end;
  end;

  /// <summary>
  ///   A nullable type can represent the normal range of values for its
  ///   underlying value type, plus an additional <c>Null</c> value.
  /// </summary>
  /// <typeparam name="T">
  ///   The underlying value type of the <see cref="Nullable&lt;T&gt;" />
  ///   generic type.
  /// </typeparam>
  Maybe<T> = record
  private
    fValue: T;
    fHasValue: string;
    class var fComparer: IEqualityComparer<T>;
    class function EqualsComparer(const left, right: T): Boolean; static;
    class function EqualsInternal(const left, right: T): Boolean; static; inline;
    function GetValue: T; inline;
    function GetHasValue: Boolean; inline;
  public
    /// <summary>
    ///   Initializes a new instance of the <see cref="Nullable&lt;T&gt;" />
    ///   structure to the specified value.
    /// </summary>
    constructor Create(const value: T); overload;

    /// <summary>
    ///   Initializes a new instance of the <see cref="Nullable&lt;T&gt;" />
    ///   structure to the specified value.
    /// </summary>
    constructor Create(const value: Variant); overload;

    /// <summary>
    ///   Retrieves the value of the current <see cref="Nullable&lt;T&gt;" />
    ///   object, or the specified default value.
    /// </summary>
    /// <param name="defaultValue">
    ///   A value to return if the <see cref="HasValue" /> property is <c>False</c>
    ///    .
    /// </param>
    /// <returns>
    ///   The value of the <see cref="Value" /> property if the <see cref="HasValue" />
    ///    property is true; otherwise, the <paramref name="defaultValue" />
    ///   parameter.
    /// </returns>
    /// <remarks>
    ///   The <see cref="GetValueOrDefault" /> method returns a value even if
    ///   the <see cref="HasValue" /> property is false (unlike the <see cref="Value" />
    ///    property, which throws an exception).
    /// </remarks>
    function GetValueOrDefault(const defaultValue: T): T; overload;

    /// <summary>
    ///   Determines whether two nullable value are equal.
    /// </summary>
    /// <remarks>
    ///   <para>
    ///     If both two nullable values are null, return true;
    ///   </para>
    ///   <para>
    ///     If either one is null, return false;
    ///   </para>
    ///   <para>
    ///     else compares their values as usual.
    ///   </para>
    /// </remarks>
    function Equals(const other: Maybe<T>): Boolean;

    function ToString: string;

    /// <summary>
    ///   Returns the stored value as variant.
    /// </summary>
    /// <exception cref="EInvalidCast">
    ///   The type of T cannot be cast to Variant
    /// </exception>
    function ToVariant: Variant;

    /// <summary>
    ///   Gets the stored value. Returns <c>False</c> if it does not contain a
    ///   value.
    /// </summary>
    function TryGetValue(out value: T): Boolean; inline;

    /// <summary>
    ///   Gets a value indicating whether the current <see cref="Nullable&lt;T&gt;" />
    ///    structure has a value.
    /// </summary>
    property HasValue: Boolean read GetHasValue;

    /// <summary>
    ///   Gets the value of the current <see cref="Nullable&lt;T&gt;" /> value.
    /// </summary>
    /// <exception cref="Spring|EInvalidOperationException">
    ///   Raised if the value is null.
    /// </exception>
    property Value: T read GetValue;

    class operator Implicit(const value: Maybe.Null): Maybe<T>;
    class operator Implicit(const value: T): Maybe<T>;

    class operator Explicit(const value: Variant): Maybe<T>;
    class operator Explicit(const value: Maybe<T>): T; inline;

    class operator Equal(const left, right: Maybe<T>): Boolean; inline;
    class operator Equal(const left: Maybe<T>; const right: Maybe.Null): Boolean; inline;
    class operator Equal(const left: Maybe<T>; const right: T): Boolean; inline;
    class operator NotEqual(const left, right: Maybe<T>): Boolean; inline;
    class operator NotEqual(const left: Maybe<T>; const right: Maybe.Null): Boolean; inline;
    class operator NotEqual(const left: Maybe<T>; const right: T): Boolean; inline;
  end;


implementation

uses
  Math,
  DateUtils,
  Spring;


{
function VarIsNullOrEmpty(const value: Variant): Boolean;
begin
  Result := FindVarData(value).VType in [varEmpty, varNull];
end;
}


constructor Maybe<T>.Create(const value: T);
begin
  fValue := value;
  fHasValue := Maybe.HasValue;
end;

constructor Maybe<T>.Create(const value: Variant);
var
  v: TValue;
begin
  if not VarIsNullOrEmpty(value) then
  begin
    v := TValue.FromVariant(value);
    fValue := v.AsType<T>;
    fHasValue := Maybe.HasValue;
  end
  else
  begin
    fHasValue := '';
    fValue := Default(T);
  end;
end;

function Maybe<T>.GetHasValue: Boolean;
begin
  Result := fHasValue <> '';
end;

function Maybe<T>.GetValue: T;
begin
  if not HasValue then
    raise EInvalidOperationException.Create('Maybe Has No Value') at ReturnAddress;
  Result := fValue;
end;

function Maybe<T>.GetValueOrDefault(const defaultValue: T): T;
begin
  if HasValue then
    Result := fValue
  else
    Result := defaultValue;
end;

class function Maybe<T>.EqualsComparer(const left, right: T): Boolean;
begin
  if not Assigned(fComparer) then
    fComparer := TEqualityComparer<T>.Default;
  Result := fComparer.Equals(left, right);
end;

class function Maybe<T>.EqualsInternal(const left, right: T): Boolean;
begin
  case TType.Kind<T> of
    tkInteger, tkEnumeration:
    begin
      case SizeOf(T) of
        1: Result := PByte(@left)^ = PByte(@right)^;
        2: Result := PWord(@left)^ = PWord(@right)^;
        4: Result := PCardinal(@left)^ = PCardinal(@right)^;
      end;
    end;
{$IFNDEF NEXTGEN}
    tkChar: Result := PAnsiChar(@left)^ = PAnsiChar(@right)^;
    tkString: Result := PShortString(@left)^ = PShortString(@right)^;
    tkLString: Result := PAnsiString(@left)^ = PAnsiString(@right)^;
    tkWString: Result := PWideString(@left)^ = PWideString(@right)^;
{$ENDIF}
    tkFloat:
    begin
      if TypeInfo(T) = TypeInfo(Single) then
        Result := Math.SameValue(PSingle(@left)^, PSingle(@right)^)
      else if TypeInfo(T) = TypeInfo(Double) then
        Result := Math.SameValue(PDouble(@left)^, PDouble(@right)^)
      else if TypeInfo(T) = TypeInfo(Extended) then
        Result := Math.SameValue(PExtended(@left)^, PExtended(@right)^)
      else if TypeInfo(T) = TypeInfo(TDateTime) then
        Result := SameDateTime(PDateTime(@left)^, PDateTime(@right)^)
      else
        case GetTypeData(TypeInfo(T)).FloatType of
          ftSingle: Result := Math.SameValue(PSingle(@left)^, PSingle(@right)^);
          ftDouble: Result := Math.SameValue(PDouble(@left)^, PDouble(@right)^);
          ftExtended: Result := Math.SameValue(PExtended(@left)^, PExtended(@right)^);
          ftComp: Result := PComp(@left)^ = PComp(@right)^;
          ftCurr: Result := PCurrency(@left)^ = PCurrency(@right)^;
        end;
    end;
    tkWChar: Result := PWideChar(@left)^ = PWideChar(@right)^;
    tkInt64: Result := PInt64(@left)^ = PInt64(@right)^;
    tkUString: Result := PUnicodeString(@left)^ = PUnicodeString(@right)^;
  else
    Result := EqualsComparer(left, right);
  end;
end;

function Maybe<T>.Equals(const other: Maybe<T>): Boolean;
begin
  if not HasValue then
    Exit(not other.HasValue);
  if not other.HasValue then
    Exit(False);
  Result := EqualsInternal(fValue, other.fValue);
end;

class operator Maybe<T>.Implicit(const value: T): Maybe<T>;
begin
  Result.fValue := value;
  Result.fHasValue := Maybe.HasValue;
end;

{$IFDEF IMPLICIT_Maybe}
class operator Maybe<T>.Implicit(const value: Maybe<T>): T;
begin
  Result := value.Value;
end;
{$ENDIF}

{$IFDEF UNSAFE_Maybe}
class operator Maybe<T>.Implicit(const value: Maybe<T>): Variant;
var
  v: TValue;
begin
  if value.HasValue then
  begin
    v := TValue.From<T>(value.fValue);
    if v.IsType<Boolean> then
      Result := v.AsBoolean
    else
      Result := v.AsVariant;
  end
  else
    Result := Null;
end;

class operator Maybe<T>.Implicit(const value: Variant): Maybe<T>;
var
  v: TValue;
begin
  if not VarIsNullOrEmpty(value) then
  begin
    v := TValue.FromVariant(value);
    Result.fValue := v.AsType<T>;
    Result.fHasValue := Maybe.HasValue;
  end
  else
    Result := Default(Maybe<T>);
end;
{$ENDIF}

class operator Maybe<T>.Explicit(const value: Variant): Maybe<T>;
var
  v: TValue;
begin
  if not VarIsNullOrEmpty(value) then
  begin
    v := TValue.FromVariant(value);
    Result.fValue := v.AsType<T>;
    Result.fHasValue := Maybe.HasValue;
  end
  else
    Result := Default(Maybe<T>);
end;

class operator Maybe<T>.Explicit(const value: Maybe<T>): T;
begin
  Result := value.Value;
end;

class operator Maybe<T>.Implicit(const value: Maybe.Null): Maybe<T>;
begin
  Result.fValue := Default(T);
  Result.fHasValue := '';
end;

class operator Maybe<T>.Equal(const left, right: Maybe<T>): Boolean;
begin
  Result := left.Equals(right);
end;

class operator Maybe<T>.Equal(const left: Maybe<T>;
  const right: T): Boolean;
begin
  if left.fHasValue = '' then
    Exit(False);
  Result := EqualsInternal(left.fValue, right);
end;

class operator Maybe<T>.Equal(const left: Maybe<T>;
  const right: Maybe.Null): Boolean;
begin
  Result := left.fHasValue = '';
end;

class operator Maybe<T>.NotEqual(const left, right: Maybe<T>): Boolean;
begin
  Result := not left.Equals(right);
end;

class operator Maybe<T>.NotEqual(const left: Maybe<T>;
  const right: Maybe.Null): Boolean;
begin
  Result := left.fHasValue <> '';
end;

class operator Maybe<T>.NotEqual(const left: Maybe<T>;
  const right: T): Boolean;
begin
  if left.fHasValue = '' then
    Exit(True);
  Result := not EqualsInternal(left.fValue, right);
end;

function Maybe<T>.ToString: string;
var
  v: TValue;
begin
  if HasValue then
  begin
    v := TValue.From<T>(fValue);
    Result := v.ToString;
  end
  else
    Result := 'Null';
end;

function Maybe<T>.ToVariant: Variant;
var
  v: TValue;
begin
  if HasValue then
  begin
    v := TValue.From<T>(fValue);
    if v.IsType<Boolean> then
      Result := v.AsBoolean
    else
      Result := v.AsVariant;
  end
  else
    Result := Null;
end;

function Maybe<T>.TryGetValue(out value: T): Boolean;
begin
  Result := fHasValue <> '';
  if Result then
    value := fValue;
end;

end.