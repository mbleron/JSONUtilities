# JSONUtilities - A Collection of PL/SQL JSON Utilities

## JSON_TO_XML

`JSON_TO_XML` procedure is an implementation of XPath 3.1 function [fn:json-to-xml](https://www.w3.org/TR/xpath-functions-31/#func-json-to-xml).

It converts a JSON text content, provided in the form of a CLOB, into an XML representation (XMLTYPE) according to [this mapping](https://www.w3.org/TR/xpath-functions-31/#json-to-xml-mapping).

The XML output conforms to the [schema-for-json.xsd](https://www.w3.org/TR/xpath-functions-31/schema-for-json.xsd) schema.

In short : 

A JSON object `{ ... }` is converted to an XML `<map> ... </map>` element.  
A JSON array `[ ... ]` is converted to an XML `<array> ... </array>` element.

and for scalar types : 

JSON string `"Hello!"` ➜ `<string>Hello!</string>`  
JSON number `123.45` ➜ `<number>Hello!</number>`  
JSON boolean `true` / `false` ➜ `<boolean>true</boolean>` / `<boolean>false</boolean>`  
JSON null `null` ➜ `<null/>`

When the JSON element is an object member, a "key" attribute is added to the XML element to represent its name, e.g.

`{"item":"Hello!"}` ➜ `<map><string key="item">Hello!</string></map>`


### Example

JSON input :  

```json
{
  "_id":"53e3c6ed-9bfc-2730-e053-0100007f6afb",
  "content":{
    "name":"obj1",
    "type":1,
    "isNew":true,
    "clientId":null,
    "values":[
      {"name":"x", "v":1},
      {"name":"y", "v":2}
    ]
  }
}
```
XML output :  
```xml
<map xmlns="http://www.w3.org/2005/xpath-functions">
  <string key="_id">53e3c6ed-9bfc-2730-e053-0100007f6afb</string>
  <map key="content">
    <string key="name">obj1</string>
    <number key="type">1</number>
    <boolean key="isNew">true</boolean>
    <null key="clientId"/>
    <array key="values">
      <map>
        <string key="name">x</string>
        <number key="v">1</number>
      </map>
      <map>
        <string key="name">y</string>
        <number key="v">2</number>
      </map>
    </array>
  </map>
</map>
```

## XML_TO_JSON

`XML_TO_JSON` procedure is an implementation of XPath 3.1 function [fn:xml-to-json](https://www.w3.org/TR/xpath-functions-31/#func-xml-to-json).  

It is the inverse function of `JSON_TO_XML`, such that <code>XML_TO_JSON(JSON_TO_XML(_json_doc_)) = _json_doc_</code>, and <code>JSON_TO_XML(XML_TO_JSON(_xml_doc_)) = _xml_doc_</code>.  

The input XML document MUST conform to the [schema-for-json.xsd](https://www.w3.org/TR/xpath-functions-31/schema-for-json.xsd) schema.  

