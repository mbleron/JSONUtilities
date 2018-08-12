create or replace package xutl_json is

  function xml_to_json (input in xmltype) return clob;
  function json_to_xml (input in clob) return xmltype;

end xutl_json;
/
