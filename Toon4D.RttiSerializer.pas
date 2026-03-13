unit Toon4D.RttiSerializer;

{
  RTTI-based object <-> JSON serializer for Toon4Delphi.

  - Converts Delphi objects (published properties) to TJSONObject
  - Applies TJSONObject values back to object instances
  - Extended type support:

    * Sets        (tkSet)           -> JSON number (bitmask)      [round-trip]
    * TStrings    (collections)     -> JSON array of strings      [round-trip]
    * Dyn arrays  (tkDynArray)      -> JSON array                 [serialize only]
    * Records     (tkRecord)        -> JSON object of fields      [serialize only]
    * Interfaces  (tkInterface)     -> treated as nullable/opaque (no round-trip)

  NOTE:
    - Generic collections (TList<T>, TObjectList<T>, etc.) are NOT yet handled;
      they still behave as nested objects (no item serialization).
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.JSON;

type
  /// <summary>
  ///   RTTI-based helper for converting Delphi objects to/from JSON.
  /// </summary>
  TToonRttiSerializer = class
  private
    class procedure AddPrimitiveToJSON(AJSON: TJSONObject;
      const AName: string; const AValue: TValue); static;
    class function RecordToJSON(const AValue: TValue; AType: TRttiType): TJSONObject; static;
    class function DynArrayToJSON(const AValue: TValue; AElementType: TRttiType): TJSONArray; static;
    class function TStringsToJSON(AStrings: TStrings): TJSONArray; static;
    class procedure JSONToTStrings(const AJSON: TJSONArray; AStrings: TStrings); static;
  public
    /// <summary>
    ///   Serializes a Delphi object instance to a JSON object.
    ///   Only published, readable properties are considered.
    /// </summary>
    class function ObjectToJSON(AObject: TObject): TJSONObject; static;

    /// <summary>
    ///   Applies values from a JSON object to a Delphi object instance.
    ///   Only published, writable properties are considered.
    ///   Extended support:
    ///     - Sets    (as integer bitmask)
    ///     - TStrings (as string array)
    ///
    ///   Dynamic arrays and records are currently NOT written back (serialize-only).
    /// </summary>
    class procedure JSONToObject(const AJSON: TJSONObject; AInstance: TObject); static;
  end;

implementation

{ TToonRttiSerializer }

class procedure TToonRttiSerializer.AddPrimitiveToJSON(AJSON: TJSONObject;
  const AName: string; const AValue: TValue);
var
  LBool: Boolean;
begin
  case AValue.Kind of
    tkInteger, tkInt64:
      AJSON.AddPair(AName, TJSONNumber.Create(AValue.AsInt64));

    tkFloat:
      AJSON.AddPair(AName, TJSONNumber.Create(AValue.AsExtended));

    tkEnumeration:
      begin
        if AValue.TypeInfo = TypeInfo(Boolean) then
        begin
          LBool := AValue.AsBoolean;
          AJSON.AddPair(AName, TJSONBool.Create(LBool));
        end
        else
          AJSON.AddPair(AName, AValue.ToString);
      end;

    tkUString, tkString, tkWString, tkLString:
      AJSON.AddPair(AName, AValue.AsString);

    tkSet:
      // serialize set as integer bitmask
      AJSON.AddPair(AName, TJSONNumber.Create(AValue.AsOrdinal));
  else
    // Anything else is ignored here (class/record/array/interface etc.)
  end;
end;

class function TToonRttiSerializer.RecordToJSON(const AValue: TValue;
  AType: TRttiType): TJSONObject;
var
  LRecJSON: TJSONObject;
  LField: TRttiField;
  LFieldValue: TValue;
  LPtr: Pointer;
begin
  LRecJSON := TJSONObject.Create;
  LPtr := AValue.GetReferenceToRawData;

  for LField in AType.GetFields do
  begin
    LFieldValue := LField.GetValue(LPtr);
    // For now, only primitive-like fields are serialized.
    case LFieldValue.Kind of
      tkInteger, tkInt64, tkFloat, tkEnumeration,
      tkUString, tkString, tkWString, tkLString, tkSet:
        AddPrimitiveToJSON(LRecJSON, LField.Name, LFieldValue);
    else
      // nested records/classes/dynarrays inside a record are ignored in v1
    end;
  end;

  Result := LRecJSON;
end;

class function TToonRttiSerializer.DynArrayToJSON(
  const AValue: TValue; AElementType: TRttiType): TJSONArray;
var
  LArrJSON: TJSONArray;
  I, LLen: Integer;
  LElem: TValue;
  LObj: TJSONObject;
begin
  LArrJSON := TJSONArray.Create;
  LLen := AValue.GetArrayLength;

  for I := 0 to LLen - 1 do
  begin
    LElem := AValue.GetArrayElement(I);

    case AElementType.TypeKind of

      // --- Primitive element types ---
      tkInteger, tkInt64:
        LArrJSON.AddElement(TJSONNumber.Create(LElem.AsInt64));

      tkFloat:
        LArrJSON.AddElement(TJSONNumber.Create(LElem.AsExtended));

      tkEnumeration:
        begin
          if AElementType.Handle = TypeInfo(Boolean) then
            LArrJSON.AddElement(TJSONBool.Create(LElem.AsBoolean))
          else
            LArrJSON.AddElement(TJSONString.Create(LElem.ToString));
        end;

      tkUString, tkString, tkWString, tkLString:
        LArrJSON.AddElement(TJSONString.Create(LElem.AsString));

      tkSet:
        LArrJSON.AddElement(TJSONNumber.Create(LElem.AsOrdinal));

      // --- Record elements ---
      tkRecord:
        begin
          LObj := RecordToJSON(LElem, AElementType);
          LArrJSON.AddElement(LObj);
        end;

      // --- Class elements ---
      tkClass:
        begin
          if LElem.AsObject <> nil then
            LArrJSON.AddElement(ObjectToJSON(LElem.AsObject))
          else
            LArrJSON.AddElement(TJSONNull.Create);
        end;

    else
      // Unsupported element type: skip
    end;
  end;

  Result := LArrJSON;
end;


class function TToonRttiSerializer.TStringsToJSON(AStrings: TStrings): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  if AStrings = nil then
    Exit;

  for I := 0 to AStrings.Count - 1 do
    Result.AddElement(TJSONString.Create(AStrings[I]));
end;

class procedure TToonRttiSerializer.JSONToTStrings(const AJSON: TJSONArray;
  AStrings: TStrings);
var
  I: Integer;
  LVal: TJSONValue;
begin
  if (AStrings = nil) or (AJSON = nil) then
    Exit;

  AStrings.Clear;
  for I := 0 to AJSON.Count - 1 do
  begin
    LVal := AJSON.Items[I];
    AStrings.Add(LVal.Value);
  end;
end;

class function TToonRttiSerializer.ObjectToJSON(AObject: TObject): TJSONObject;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LJSON: TJSONObject;
  LValue: TValue;
  LClassType: TRttiInstanceType;
  LStrings: TStrings;
begin
  if AObject = nil then
    Exit(TJSONObject.Create);

  LJSON := TJSONObject.Create;
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AObject.ClassType);
    LClassType := LType as TRttiInstanceType;

    for LProp in LClassType.GetProperties do
    begin
      if LProp.Visibility <> mvPublished then
        Continue;
      if not LProp.IsReadable then
        Continue;

      LValue := LProp.GetValue(AObject);

      case LProp.PropertyType.TypeKind of
        tkInteger, tkInt64, tkFloat, tkEnumeration,
        tkUString, tkString, tkWString, tkLString, tkSet:
          AddPrimitiveToJSON(LJSON, LProp.Name, LValue);

        tkRecord:
          begin
            // serialize record as JSON object of its fields (primitive only)
            LJSON.AddPair(LProp.Name,
              RecordToJSON(LValue, LProp.PropertyType));
          end;

        tkDynArray:
          begin
            // serialize dynamic array to JSON array (primitive/record/class elems only)
            LJSON.AddPair(LProp.Name,
              DynArrayToJSON(LValue, (LProp.PropertyType as TRttiDynamicArrayType).ElementType));
          end;

        tkClass:
          begin
            // Special-case TStrings as "collection"
            if LValue.AsObject is TStrings then
            begin
              LStrings := TStrings(LValue.AsObject);
              LJSON.AddPair(LProp.Name, TStringsToJSON(LStrings));
            end
            else
            begin
              // Nested class: recurse
              if LValue.AsObject <> nil then
                LJSON.AddPair(LProp.Name, ObjectToJSON(LValue.AsObject))
              else
                LJSON.AddPair(LProp.Name, TJSONNull.Create);
            end;
          end;

        tkInterface:
          begin
            // For now: opaque; only null/non-null is represented.
            if (not LValue.IsEmpty) and (LValue.AsInterface <> nil) then
              LJSON.AddPair(LProp.Name, TJSONString.Create('<interface>'))
            else
              LJSON.AddPair(LProp.Name, TJSONNull.Create);
          end;
      else
        // Other kinds are ignored in v1
      end;
    end;

    Result := LJSON;
  finally
    LContext.Free;
  end;
end;

class procedure TToonRttiSerializer.JSONToObject(const AJSON: TJSONObject;
  AInstance: TObject);
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LPair: TJSONPair;
  LValue: TValue;
  LNum: Int64;
  LStrings: TStrings;
begin
  if (AJSON = nil) or (AInstance = nil) then
    Exit;

  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AInstance.ClassType);
    for LProp in LType.GetProperties do
    begin
      if LProp.Visibility <> mvPublished then
        Continue;
      if not LProp.IsWritable then
        Continue;

      LPair := AJSON.Get(LProp.Name);
      if LPair = nil then
        Continue;

      if LPair.JsonValue is TJSONNull then
      begin
        if LProp.PropertyType.TypeKind = tkInterface then
          LProp.SetValue(AInstance, TValue.Empty); // set interface to nil
        Continue;
      end;

      case LProp.PropertyType.TypeKind of
        tkInteger, tkInt64:
          begin
            if LPair.JsonValue is TJSONNumber then
              LProp.SetValue(AInstance,
                StrToInt64Def(TJSONNumber(LPair.JsonValue).ToString, 0));
          end;

        tkFloat:
          begin
            if LPair.JsonValue is TJSONNumber then
              LProp.SetValue(AInstance,
                StrToFloatDef(TJSONNumber(LPair.JsonValue).ToString, 0.0));
          end;

        tkEnumeration:
          begin
            if LProp.PropertyType.Handle = TypeInfo(Boolean) then
            begin
              if LPair.JsonValue is TJSONBool then
                LProp.SetValue(AInstance, TJSONBool(LPair.JsonValue).AsBoolean)
              else
                LProp.SetValue(AInstance, SameText(LPair.JsonValue.Value, 'true'));
            end
            else
            begin
              LValue := TValue.FromOrdinal(
                LProp.PropertyType.Handle,
                GetEnumValue(LProp.PropertyType.Handle, LPair.JsonValue.Value));
              LProp.SetValue(AInstance, LValue);
            end;
          end;

        tkUString, tkString, tkWString, tkLString:
          begin
            LProp.SetValue(AInstance, LPair.JsonValue.Value);
          end;

        tkSet:
          begin
            // Set represented as integer bitmask
            if LPair.JsonValue is TJSONNumber then
            begin
              LNum := StrToInt64Def(TJSONNumber(LPair.JsonValue).ToString, 0);
              LValue := TValue.FromOrdinal(LProp.PropertyType.Handle, LNum);
              LProp.SetValue(AInstance, LValue);
            end;
          end;

        tkClass:
          begin
            // TStrings as array of strings
            if (LPair.JsonValue is TJSONArray) and
               LProp.PropertyType.IsInstance and
               LProp.PropertyType.AsInstance.MetaclassType.InheritsFrom(TStrings) then
            begin
              LValue := LProp.GetValue(AInstance);
              if (LValue.Kind = tkClass) and (LValue.AsObject is TStrings) then
              begin
                LStrings := TStrings(LValue.AsObject);
                JSONToTStrings(TJSONArray(LPair.JsonValue), LStrings);
              end;
            end
            else if LPair.JsonValue is TJSONObject then
            begin
              // nested object: recurse if already created
              LValue := LProp.GetValue(AInstance);
              if (LValue.Kind = tkClass) and (LValue.AsObject <> nil) then
                JSONToObject(TJSONObject(LPair.JsonValue), LValue.AsObject);
            end;
          end;

        tkInterface:
          begin
            // Currently no automatic reconstruction of interface instances.
            // Non-null JSON is ignored; null already handled above.
          end;

        // tkDynArray, tkRecord:
        // Currently deserialize is not implemented in v1 (serialize-only).
      end;
    end;
  finally
    LContext.Free;
  end;
end;

end.

