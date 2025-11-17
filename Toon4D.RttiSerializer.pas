unit Toon4D.RttiSerializer;

{
  RTTI-based object <-> JSON serializer for Toon4Delphi.

  - Converts Delphi objects (published properties) to TJSONObject
  - Applies TJSONObject values back to object instances
  - Used as a building block by the main Toon unit
}

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.JSON;

type
  /// <summary>
  ///   RTTI-based helper for converting Delphi objects to/from JSON.
  /// </summary>
  TToonRttiSerializer = class
  public
    /// <summary>
    ///   Serializes a Delphi object instance to a JSON object.
    ///   Only published, readable properties are considered.
    /// </summary>
    class function ObjectToJSON(AObject: TObject): TJSONObject; static;

    /// <summary>
    ///   Applies values from a JSON object to a Delphi object instance.
    ///   Only published, writable properties are considered.
    /// </summary>
    class procedure JSONToObject(const AJSON: TJSONObject; AInstance: TObject); static;
  end;

implementation

{ TToonRttiSerializer }

class function TToonRttiSerializer.ObjectToJSON(AObject: TObject): TJSONObject;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LJSON: TJSONObject;
  LValue: TValue;
  LBool: Boolean;
begin
  if AObject = nil then
    Exit(TJSONObject.Create);

  LJSON := TJSONObject.Create;
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AObject.ClassType);
    for LProp in LType.GetProperties do
    begin
      if LProp.Visibility <> mvPublished then
        Continue;
      if not LProp.IsReadable then
        Continue;

      LValue := LProp.GetValue(AObject);

      case LValue.Kind of
        tkInteger, tkInt64:
          LJSON.AddPair(LProp.Name, TJSONNumber.Create(LValue.AsInt64));

        tkFloat:
          LJSON.AddPair(LProp.Name, TJSONNumber.Create(LValue.AsExtended));

        tkEnumeration:
          begin
            if LValue.TypeInfo = TypeInfo(Boolean) then
            begin
              LBool := LValue.AsBoolean;
              LJSON.AddPair(LProp.Name, TJSONBool.Create(LBool));
            end
            else
              LJSON.AddPair(LProp.Name, LValue.ToString);
          end;

        tkUString, tkString, tkWString, tkLString:
          LJSON.AddPair(LProp.Name, LValue.AsString);

        tkClass:
          begin
            if LValue.AsObject <> nil then
              LJSON.AddPair(LProp.Name, ObjectToJSON(LValue.AsObject))
            else
              LJSON.AddPair(LProp.Name, TJSONNull.Create);
          end;
      else
        // Other kinds (sets, arrays, interfaces, etc.) are ignored in v1.
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
        Continue;

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

        tkClass:
          begin
            if LPair.JsonValue is TJSONObject then
            begin
              // For nested classes we assume they are already created.
              LValue := LProp.GetValue(AInstance);
              if (LValue.Kind = tkClass) and (LValue.AsObject <> nil) then
                JSONToObject(TJSONObject(LPair.JsonValue), LValue.AsObject);
            end;
          end;
      end;
    end;
  finally
    LContext.Free;
  end;
end;

end.

