# 🎯 Toon4D  
**TOON (Token-Oriented Object Notation) support for Delphi**
Read more [Read more about TOON](https://www.freecodecamp.org/news/what-is-toon-how-token-oriented-object-notation-could-change-how-ai-sees-data/)

A lightweight **Token-Oriented Object Notation (TOON)** library for Delphi.

TOON is a compact, human-readable, token-efficient data format designed for **AI / LLM workflows**.  
This library brings full **TOON ↔ JSON ↔ Delphi RTTI object** conversion into Delphi, with zero dependencies and full **Win32/Win64** compatibility.

---

## ✨ Features

- **Object → TOON** (via RTTI, published properties)  
- **TOON → Object** (via JSON intermediate stage)  
- **JSON → TOON**  
- **TOON → JSON**  
- Simple fluent API via **`TToonBuilder`**  
- Works on **Win32 and Win64**  
- **No external libraries required**

---

## 🚀 Quick Examples

### **Delphi Object → TOON**

```pascal
type
  TUser = class
  private
    FId: Integer;
    FName: string;
  published
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

var
  LUser: TUser;
  LToon: string;
begin
  LUser := TUser.Create;
  LUser.Id := 1;
  LUser.Name := 'Alice';

  LToon := TToon.ObjectToToon(LUser);

  {
  Id: 1
  Name: Alice
  }
end;
```

### JSON → TOON

```pascal
var
  LJSON, LToon: string;
begin
  LJSON := '{"users":[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]}';
  LToon := TToon.JSONToToon(LJSON);

  (*
  users[2]{id,name}:
    1,Alice
    2,Bob
  *)
end;

```

### TOON → JSON
```pascal
var
  LToon, LJSON: string;
begin
  LToon :=
    'users[2]{id,name}:' + sLineBreak +
    '  1,Alice' + sLineBreak +
    '  2,Bob';

  LJSON := TToon.ToonToJSON(LToon);
end;

```

## Fluent Builder
```pascal
var
  LToon, LJSON: string;
begin
  LToon := TToonBuilder.FromJSON('{"x":1,"y":2}').AsToon;
  LJSON := TToonBuilder.FromToon(LToon).AsJSON;
end;

```

### From Object → TOON
```pascal
type
  TPoint = class
  private
    FX: Integer;
    FY: Integer;
  published
    property X: Integer read FX write FX;
    property Y: Integer read FY write FY;
  end;

var
  LObj: TPoint;
  LToon: string;
begin
  LObj := TPoint.Create;
  LObj.X := 10;
  LObj.Y := 20;

  LToon := TToonBuilder.FromObject(LObj).AsToon;

  {
  X: 10
  Y: 20
  }
end;

```



## 📘 Supported Types by RTTI serializer (v1)

- Integer / Int64
- Float
- Boolean
- Enums
- String types
- Nested classes (already instantiated)

## Not yet included:
- Sets
- Dynamic arrays / collections
- Records
- Interfaces


### 📄 License
MIT - free to use, modify, and extend.


<hr>
<p align="center">
<img src="https://i0.wp.com/blogs.embarcadero.com/wp-content/uploads/2022/11/dlogonew-5582740.png?resize=254%2C242&ssl=1" alt="Delphi">
</p>
<h5 align="center">
Made with :heart: on Delphi
</h5>
