unit Test.Toon4D;

interface
{$M+}

uses
  System.Generics.Collections,
  DUnitX.TestFramework;

type
  [TestFixture]
  TToonTests = class
  public
    [Test]
    procedure JSON_Object_RoundTrip;

    [Test]
    procedure JSON_ArrayOfObjects_RoundTrip;

    [Test]
    procedure Object_RoundTrip_SimpleClass;
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  Toon4D.Core,
  Toon4D.RttiSerializer;

type
  TUser = class
  private
    FId: Integer;
    FName: string;
  published
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

{ TToonTests }

procedure TToonTests.JSON_Object_RoundTrip;
var
  LJSON: string;
  LToon: string;
  LBackJSON: string;
  LObj: TJSONObject;
begin
  LJSON := '{"id":1,"name":"Alice"}';

  LToon := TToon.JSONToToon(LJSON);
  LBackJSON := TToon.ToonToJSON(LToon);

  LObj := TJSONObject.ParseJSONValue(LBackJSON) as TJSONObject;
  try
    Assert.IsNotNull(LObj);
    Assert.AreEqual(1, LObj.GetValue<Integer>('id'));
    Assert.AreEqual('Alice', LObj.GetValue<string>('name'));
  finally
    LObj.Free;
  end;
end;

procedure TToonTests.JSON_ArrayOfObjects_RoundTrip;
var
  LJSON: string;
  LToon: string;
  LBackJSON: string;
  LRoot: TJSONObject;
  LArr: TJSONArray;
  LUserObj: TJSONObject;
begin
  LJSON := '{"users":[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]}';

  LToon := TToon.JSONToToon(LJSON);
  LBackJSON := TToon.ToonToJSON(LToon);

  LRoot := TJSONObject.ParseJSONValue(LBackJSON) as TJSONObject;
  try
    Assert.IsNotNull(LRoot);

    LArr := LRoot.GetValue<TJSONArray>('users');
    Assert.IsNotNull(LArr);
    Assert.AreEqual(2, LArr.Count);

    LUserObj := LArr.Items[0] as TJSONObject;
    Assert.AreEqual(1, LUserObj.GetValue<Integer>('id'));
    Assert.AreEqual('Alice', LUserObj.GetValue<string>('name'));

    LUserObj := LArr.Items[1] as TJSONObject;
    Assert.AreEqual(2, LUserObj.GetValue<Integer>('id'));
    Assert.AreEqual('Bob', LUserObj.GetValue<string>('name'));
  finally
    LRoot.Free;
  end;
end;

procedure TToonTests.Object_RoundTrip_SimpleClass;
var
  LSrc, LDest: TUser;
  LToon: string;
begin
  LSrc := TUser.Create;
  LDest := TUser.Create;
  try
    LSrc.Id := 42;
    LSrc.Name := 'Alice';

    LToon := TToon.ObjectToToon(LSrc);
    TToon.ToonToObject(LToon, LDest);

    Assert.AreEqual(42, LDest.Id);
    Assert.AreEqual('Alice', LDest.Name);
  finally
    LSrc.Free;
    LDest.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TToonTests);

end.
