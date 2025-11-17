unit Toon4D.Core;

{
  TOON (Token-Oriented Object Notation) support for Delphi.

  Features:
  - Object <-> TOON via RTTI (through Toon.RttiSerializer)
  - TOON <-> JSON conversion
  - 32-bit and 64-bit compatible (no pointer arithmetic)
  - Simple fluent TToonBuilder record
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  Toon4D.RttiSerializer;

type
  /// <summary>
  ///   Central static TOON helper for conversion.
  /// </summary>
  TToon = class
  private
    class function Indent(const ALevel: Integer): string; static;

    class function JSONValueToToon(const AName: string; AValue: TJSONValue;
      const AIndent: Integer): string; static;

    class function IsArrayOfPrimitives(AArray: TJSONArray): Boolean; static;
    class function IsArrayOfHomogeneousObjects(AArray: TJSONArray;
      out AFieldNames: TArray<string>): Boolean; static;

    class function ParseToonToJSON(const AToon: string): TJSONObject; static;
    class procedure ParseObject(const ALines: TArray<string>;
      var AIndex: Integer; const AIndent: Integer; ATarget: TJSONObject); static;
    class function ParseScalarValue(const AText: string): TJSONValue; static;
    class function ParseArrayOfPrimitives(const ARows: TArray<string>): TJSONArray; static;
    class function ParseArrayOfObjects(const AFieldNames: TArray<string>;
      const ARows: TArray<string>): TJSONArray; static;

  public
    /// <summary>
    ///   Serializes a Delphi object instance to TOON text.
    /// </summary>
    class function ObjectToToon(AObject: TObject): string; static;

    /// <summary>
    ///   Deserializes TOON text into an existing Delphi object instance.
    ///   The mapping is done via an intermediate JSON representation.
    /// </summary>
    class procedure ToonToObject(const AToon: string; AInstance: TObject); static;

    /// <summary>
    ///   Converts JSON text to TOON text.
    /// </summary>
    class function JSONToToon(const AJSON: string): string; static;

    /// <summary>
    ///   Converts TOON text to JSON text.
    /// </summary>
    class function ToonToJSON(const AToon: string): string; static;
  end;

implementation

{ TToon }

class function TToon.Indent(const ALevel: Integer): string;
begin
  if ALevel <= 0 then
    Result := ''
  else
    Result := StringOfChar(' ', ALevel * 2); // 2 spaces per level
end;

class function TToon.IsArrayOfPrimitives(AArray: TJSONArray): Boolean;
var
  LValue: TJSONValue;
begin
  Result := True;
  for LValue in AArray do
  begin
    if (LValue is TJSONObject) or (LValue is TJSONArray) then
      Exit(False);
  end;
end;

class function TToon.IsArrayOfHomogeneousObjects(AArray: TJSONArray;
  out AFieldNames: TArray<string>): Boolean;
var
  LFirstObj: TJSONObject;
  LObj: TJSONValue;
  LPair: TJSONPair;
  LFieldList: TList<string>;
  LName: string;
begin
  Result := False;
  SetLength(AFieldNames, 0);

  if (AArray.Count = 0) or not (AArray.Items[0] is TJSONObject) then
    Exit;

  LFirstObj := TJSONObject(AArray.Items[0]);
  LFieldList := TList<string>.Create;
  try
    for LPair in LFirstObj do
      LFieldList.Add(LPair.JsonString.Value);

    // Check same fields in same order for all objects
    for LObj in AArray do
    begin
      if not (LObj is TJSONObject) then
        Exit(False);

      if LFieldList.Count <> TJSONObject(LObj).Count then
        Exit(False);

      for LPair in TJSONObject(LObj) do
      begin
        LName := LPair.JsonString.Value;
        if not LFieldList.Contains(LName) then
          Exit(False);
      end;
    end;

    AFieldNames := LFieldList.ToArray;
    Result := True;
  finally
    LFieldList.Free;
  end;
end;

class function TToon.JSONValueToToon(const AName: string; AValue: TJSONValue;
  const AIndent: Integer): string;
var
  LBuilder: TStringBuilder;
  LPair: TJSONPair;
  LObj: TJSONObject;
  LArr: TJSONArray;
  LFieldNames: TArray<string>;
  LRowValues: TArray<string>;
  LRow: string;
  LItem: TJSONValue;
  LField: string;
  LFirst: Boolean;
  LChildIndent: Integer;
begin
  LBuilder := TStringBuilder.Create;
  try
    if AValue is TJSONObject then
    begin
      LObj := TJSONObject(AValue);

      if AName <> '' then
      begin
        LBuilder.AppendLine(Indent(AIndent) + AName + ':');
        LChildIndent := AIndent + 1;
      end
      else
        LChildIndent := AIndent;

      for LPair in LObj do
      begin
        LBuilder.Append(JSONValueToToon(LPair.JsonString.Value,
          LPair.JsonValue, LChildIndent));
      end;
    end
    else if AValue is TJSONArray then
    begin
      LArr := TJSONArray(AValue);

      if IsArrayOfPrimitives(LArr) then
      begin
        // Inline primitive array: name[N]: v1,v2,v3
        LBuilder.Append(Indent(AIndent) + AName +
          '[' + LArr.Count.ToString + ']: ');

        LFirst := True;
        for LItem in LArr do
        begin
          if not LFirst then
            LBuilder.Append(',');
          LFirst := False;
          LBuilder.Append(LItem.Value);
        end;
        LBuilder.AppendLine;
      end
      else if IsArrayOfHomogeneousObjects(LArr, LFieldNames) then
      begin
        LBuilder.Append(Indent(AIndent) + AName +
          '[' + LArr.Count.ToString + ']{' +
          string.Join(',', LFieldNames) + '}:');
        LBuilder.AppendLine;

        for LItem in LArr do
        begin
          SetLength(LRowValues, Length(LFieldNames));
          LRowValues := nil;
          for LField in LFieldNames do
            LRowValues := LRowValues + [TJSONObject(LItem).GetValue(LField).Value];

          LRow := string.Join(',', LRowValues);
          LBuilder.AppendLine(Indent(AIndent + 1) + LRow);
        end;
      end
      else
      begin
        // Fallback: nested structures.
        LBuilder.AppendLine(Indent(AIndent) + AName +
          '[' + LArr.Count.ToString + ']:');
        for LItem in LArr do
          LBuilder.Append(JSONValueToToon('-', LItem, AIndent + 1));
      end;
    end
    else
    begin
      // Primitive value
      if AName <> '' then
        LBuilder.AppendLine(Indent(AIndent) + AName + ': ' + AValue.Value)
      else
        LBuilder.AppendLine(Indent(AIndent) + AValue.Value);
    end;

    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TToon.ObjectToToon(AObject: TObject): string;
var
  LJSON: TJSONObject;
begin
  LJSON := TToonRttiSerializer.ObjectToJSON(AObject);
  try
    Result := JSONValueToToon('', LJSON, 0);
  finally
    LJSON.Free;
  end;
end;

class function TToon.JSONToToon(const AJSON: string): string;
var
  LJSONValue: TJSONValue;
  LObj: TJSONObject;
begin
  LJSONValue := TJSONObject.ParseJSONValue(AJSON);
  if LJSONValue = nil then
    raise EArgumentException.Create('Invalid JSON input.');

  try
    if LJSONValue is TJSONObject then
    begin
      LObj := TJSONObject(LJSONValue);
      Result := JSONValueToToon('', LObj, 0);
    end
    else
      Result := JSONValueToToon('', LJSONValue, 0);
  finally
    LJSONValue.Free;
  end;
end;

class function TToon.ParseScalarValue(const AText: string): TJSONValue;
var
  LTrimmed: string;
  LInt: Int64;
  LFloat: Double;
begin
  LTrimmed := Trim(AText);

  if SameText(LTrimmed, 'null') then
    Exit(TJSONNull.Create);

  if SameText(LTrimmed, 'true') then
    Exit(TJSONBool.Create(True));

  if SameText(LTrimmed, 'false') then
    Exit(TJSONBool.Create(False));

  if TryStrToInt64(LTrimmed, LInt) then
    Exit(TJSONNumber.Create(LInt));

  if TryStrToFloat(LTrimmed, LFloat) then
    Exit(TJSONNumber.Create(LFloat));

  Result := TJSONString.Create(LTrimmed);
end;

class function TToon.ParseArrayOfPrimitives(
  const ARows: TArray<string>): TJSONArray;
var
  LRow: string;
  LParts: TArray<string>;
  LPart: string;
begin
  Result := TJSONArray.Create;

  for LRow in ARows do
  begin
    if Trim(LRow) = '' then
      Continue;

    LParts := Trim(LRow).Split([',']);
    for LPart in LParts do
      Result.AddElement(ParseScalarValue(LPart));
  end;
end;

class function TToon.ParseArrayOfObjects(const AFieldNames: TArray<string>;
  const ARows: TArray<string>): TJSONArray;
var
  LRow: string;
  LParts: TArray<string>;
  LIdx: Integer;
  LObj: TJSONObject;
begin
  Result := TJSONArray.Create;

  for LRow in ARows do
  begin
    if Trim(LRow) = '' then
      Continue;

    LParts := Trim(LRow).Split([',']);
    if Length(LParts) <> Length(AFieldNames) then
      raise EConvertError.Create('TOON row does not match header field count.');

    LObj := TJSONObject.Create;
    for LIdx := 0 to High(AFieldNames) do
      LObj.AddPair(AFieldNames[LIdx], ParseScalarValue(LParts[LIdx]));
    Result.AddElement(LObj);
  end;
end;

class procedure TToon.ParseObject(const ALines: TArray<string>;
  var AIndex: Integer; const AIndent: Integer; ATarget: TJSONObject);
var
  LLine: string;
  LTrim: string;
  LCurrentIndent: Integer;
  LPosColon: Integer;
  LKey, LRest: string;
  LPosBracketOpen, LPosBracketClose, LPosBraceOpen, LPosBraceClose: Integer;
  LArrayLenStr: string;
  LCount: Integer;
  LFieldsStr: string;
  LFieldNames: TArray<string>;
  LRows: TList<string>;
  LStartIndent: Integer;
  LRowIndent: Integer;
  LArray: TJSONArray;
  LChild: TJSONObject;
begin
  while AIndex <= High(ALines) do
  begin
    LLine := ALines[AIndex];
    LTrim := Trim(LLine);

    // skip blank lines and simple comments
    if (LTrim = '') or LTrim.StartsWith('#') or LTrim.StartsWith('//') then
    begin
      Inc(AIndex);
      Continue;
    end;

    // compute indentation (2 spaces per indent level)
    LCurrentIndent := 0;
    while (LCurrentIndent < LLine.Length) and (LLine[LCurrentIndent + 1] = ' ') do
      Inc(LCurrentIndent);
    LCurrentIndent := LCurrentIndent div 2;

    if LCurrentIndent < AIndent then
      Exit
    else if LCurrentIndent > AIndent then
      Exit;

    // detect array header: name[N]{fields}: or name[N]:
    LPosBracketOpen := LTrim.IndexOf('[');
    LPosBracketClose := LTrim.IndexOf(']');
    LPosBraceOpen := LTrim.IndexOf('{');
    LPosBraceClose := LTrim.IndexOf('}');
    LPosColon := LTrim.LastIndexOf(':');

    if (LPosBracketOpen > 0) and (LPosBracketClose > LPosBracketOpen) and
       (LPosColon = LTrim.Length - 1) then
    begin
      // name[N]{fields}: or name[N]:
      LKey := LTrim.Substring(0, LPosBracketOpen).Trim;
      LArrayLenStr := LTrim.Substring(LPosBracketOpen + 1,
        LPosBracketClose - LPosBracketOpen - 1);
      LCount := StrToIntDef(LArrayLenStr, -1);

      if (LPosBraceOpen > LPosBracketClose) and (LPosBraceClose > LPosBraceOpen) then
      begin
        // Array of objects
        LFieldsStr := LTrim.Substring(LPosBraceOpen + 1,
          LPosBraceClose - LPosBraceOpen - 1);
        LFieldNames := LFieldsStr.Split([',']);

        LRows := TList<string>.Create;
        try
          LStartIndent := AIndent + 1;
          Inc(AIndex);
          while AIndex <= High(ALines) do
          begin
            LLine := ALines[AIndex];
            LTrim := Trim(LLine);

            if (LTrim = '') or LTrim.StartsWith('#') or LTrim.StartsWith('//') then
            begin
              Inc(AIndex);
              Continue;
            end;

            LRowIndent := 0;
            while (LRowIndent < LLine.Length) and
                  (LLine[LRowIndent + 1] = ' ') do
              Inc(LRowIndent);
            LRowIndent := LRowIndent div 2;

            if LRowIndent < LStartIndent then
              Break
            else if LRowIndent > LStartIndent then
              Break
            else
            begin
              LRows.Add(LTrim);
              Inc(AIndex);
            end;
          end;

          LArray := ParseArrayOfObjects(LFieldNames, LRows.ToArray);
        finally
          LRows.Free;
        end;
      end
      else
      begin
        // Array of primitives: name[N]: v1,v2 or multi-line rows
        LRows := TList<string>.Create;
        try
          Inc(AIndex);
          LStartIndent := AIndent + 1;

          // read either inline or multiple rows
          while AIndex <= High(ALines) do
          begin
            LLine := ALines[AIndex];
            LTrim := Trim(LLine);

            if (LTrim = '') or LTrim.StartsWith('#') or LTrim.StartsWith('//') then
            begin
              Inc(AIndex);
              Continue;
            end;

            // same or deeper indent than LStartIndent?
            LRowIndent := 0;
            while (LRowIndent < LLine.Length) and (LLine[LRowIndent + 1] = ' ') do
              Inc(LRowIndent);
            LRowIndent := LRowIndent div 2;

            if LRowIndent < LStartIndent then
              Break
            else if LRowIndent > LStartIndent then
              Break
            else
            begin
              LRows.Add(LTrim);
              Inc(AIndex);
            end;
          end;

          LArray := ParseArrayOfPrimitives(LRows.ToArray);
        finally
          LRows.Free;
        end;
      end;

      if (LCount >= 0) and (LArray <> nil) and (LArray.Count <> LCount) then
      begin
        // Length mismatch could be logged; not fatal here.
        raise Exception.Create('Length mismatch');
      end;

      if LArray <> nil then
        ATarget.AddPair(LKey, LArray);

      Continue;
    end;

    // key: value   or   key:
    LPosColon := LTrim.IndexOf(':');
    if LPosColon > 0 then
    begin
      LKey := Trim(LTrim.Substring(0, LPosColon));
      LRest := '';
      if LPosColon < LTrim.Length - 1 then
        LRest := Trim(LTrim.Substring(LPosColon + 1));

      if LRest = '' then
      begin
        // Nested object header: key:
        LChild := TJSONObject.Create;
        ATarget.AddPair(LKey, LChild);
        Inc(AIndex);
        ParseObject(ALines, AIndex, AIndent + 1, LChild);
        Continue;
      end
      else
      begin
        // Scalar property on one line: key: value
        ATarget.AddPair(LKey, ParseScalarValue(LRest));
        Inc(AIndex);
        Continue;
      end;
    end
    else
    begin
      // Unknown pattern - skip
      Inc(AIndex);
    end;
  end;
end;

class function TToon.ParseToonToJSON(const AToon: string): TJSONObject;
var
  LLines: TArray<string>;
  LIdx: Integer;
  LNormalized: string;
begin
  LNormalized := AToon.Replace(#13#10, #10);
  LLines := LNormalized.Split([#10]);
  Result := TJSONObject.Create;
  LIdx := 0;
  ParseObject(LLines, LIdx, 0, Result);
end;

class function TToon.ToonToJSON(const AToon: string): string;
var
  LJSON: TJSONObject;
begin
  LJSON := ParseToonToJSON(AToon);
  try
    Result := LJSON.ToJSON;
  finally
    LJSON.Free;
  end;
end;

class procedure TToon.ToonToObject(const AToon: string; AInstance: TObject);
var
  LJSON: TJSONObject;
begin
  LJSON := ParseToonToJSON(AToon);
  try
    TToonRttiSerializer.JSONToObject(LJSON, AInstance);
  finally
    LJSON.Free;
  end;
end;

end.
