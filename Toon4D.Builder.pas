unit Toon4D.Builder;

interface

uses
  Toon4D.Core;

type

  /// <summary>
  ///   Fluent helper record for common TOON workflows.
  /// </summary>
  TToonBuilder = record
  private
    FToon: string;
  public
    /// <summary>
    ///   Creates a builder from a Delphi object instance.
    /// </summary>
    class function FromObject(AObject: TObject): TToonBuilder; static;

    /// <summary>
    ///   Creates a builder from JSON text.
    /// </summary>
    class function FromJSON(const AJSON: string): TToonBuilder; static;

    /// <summary>
    ///   Creates a builder from a TOON string.
    /// </summary>
    class function FromToon(const AToon: string): TToonBuilder; static;

    /// <summary>
    ///   Returns the internal TOON representation.
    /// </summary>
    function AsToon: string;

    /// <summary>
    ///   Returns a JSON representation of the internal TOON string.
    /// </summary>
    function AsJSON: string;

    /// <summary>
    ///   Applies the internal TOON payload to a Delphi object instance.
    /// </summary>
    procedure ApplyToObject(AInstance: TObject);
  end;

implementation

{ TToonBuilder }

class function TToonBuilder.FromJSON(const AJSON: string): TToonBuilder;
begin
  Result.FToon := TToon.JSONToToon(AJSON);
end;

class function TToonBuilder.FromObject(AObject: TObject): TToonBuilder;
begin
  Result.FToon := TToon.ObjectToToon(AObject);
end;

class function TToonBuilder.FromToon(const AToon: string): TToonBuilder;
begin
  Result.FToon := AToon;
end;

function TToonBuilder.AsJSON: string;
begin
  Result := TToon.ToonToJSON(FToon);
end;

function TToonBuilder.AsToon: string;
begin
  Result := FToon;
end;

procedure TToonBuilder.ApplyToObject(AInstance: TObject);
begin
  TToon.ToonToObject(FToon, AInstance);
end;

end.
