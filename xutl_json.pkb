create or replace package body xutl_json is

  NS_XPATH_FN          constant varchar2(100) := 'http://www.w3.org/2005/xpath-functions';
  ERR_INVALID_XML_ELT  constant varchar2(100) := 'Invalid element ''%s'' in namespace ''%s''';
  ERR_DUPLICATE_KEY    constant varchar2(100) := 'Duplicate key ''%s''';
  
  validation_error  exception;
  pragma exception_init(validation_error, -20101);

  type json_item is record (
    content      json_element_t
  , key          varchar2(4000)
  , ordinal      pls_integer
  , string_val   varchar2(32767)
  , number_val   number
  , boolean_val  boolean
  , type_val     number(2)
  , parent_item  json_element_t
  );

  procedure error (
    err_num      in number
  , err_message  in varchar2
  , arg1         in varchar2 default null
  , arg2         in varchar2 default null
  , arg3         in varchar2 default null
  )
  is
  begin
    raise_application_error(err_num, utl_lms.format_message(err_message, arg1, arg2, arg3));
  end;


  function get_child_xml (
    doc   in dbms_xmldom.DOMDocument
  , item  in json_item
  )
  return dbms_xmldom.DOMNode
  is
    node_name   varchar2(4000);
    node_value  varchar2(32767);
    node_text   dbms_xmldom.DOMText;
    node        dbms_xmldom.DOMNode;
    child_node  dbms_xmldom.DOMNode;
    element     dbms_xmldom.DOMElement;
    child_item  json_item;
    obj         json_object_t;
    arr         json_array_t;   
    keys        json_key_list;
    
  begin
    
    case 
    when item.content.is_Object then
      element := dbms_xmldom.createElement(doc, 'map', NS_XPATH_FN);
      if item.key is not null then
        dbms_xmldom.setAttribute(element, 'key', item.key);
      end if;
      node := dbms_xmldom.makeNode(element);
      obj := treat(item.content as json_object_t);
      keys := obj.get_keys();
      for i in 1 .. keys.count loop
        child_item.content := obj.get(keys(i));
        child_item.key := keys(i);
        child_item.parent_item := item.content;
        child_node := dbms_xmldom.appendChild(node, get_child_xml(doc, child_item));
      end loop;
      
    when item.content.is_Array then
      element := dbms_xmldom.createElement(doc, 'array', NS_XPATH_FN);
      if item.key is not null then
        dbms_xmldom.setAttribute(element, 'key', item.key);
      end if;
      node := dbms_xmldom.makeNode(element);
      arr := treat(item.content as json_array_t);
      for i in 0 .. arr.get_size - 1 loop
        child_item.content := arr.get(i);
        child_item.parent_item := item.content;
        child_node := dbms_xmldom.appendChild(node, get_child_xml(doc, child_item));
      end loop;
      
    when item.content.is_Scalar then      
      case 
      when item.parent_item.is_object then
        obj := treat(item.parent_item as json_object_t);
        case 
        when item.content.is_string then
          node_value := obj.get_string(item.key);
          node_name := 'string';
        when item.content.is_number then
          node_value := to_char(obj.get_Number(item.key),'TM9','nls_numeric_characters=.,');
          node_name := 'number';
        when item.content.is_boolean then
          node_value := case when obj.get_boolean(item.key) then 'true' else 'false' end;
          node_name := 'boolean';
        else
          node_name := 'null';
        end case;
      
      when item.parent_item.is_array then
        arr := treat(item.parent_item as json_array_t);
        case 
        when item.content.is_string then
          node_value := arr.get_string(item.ordinal);
          node_name := 'string';
        when item.content.is_number then
          node_value := to_char(arr.get_Number(item.ordinal),'TM9','nls_numeric_characters=.,');
          node_name := 'number';
        when item.content.is_boolean then
          node_value := case when arr.get_boolean(item.ordinal) then 'true' else 'false' end;
          node_name := 'boolean';
        else
          node_name := 'null';
        end case;
      
      end case;  
      
      element := dbms_xmldom.createElement(doc, node_name, NS_XPATH_FN);
      if item.key is not null then
        dbms_xmldom.setAttribute(element, 'key', item.key);
      end if;
      node := dbms_xmldom.makeNode(element);
      if not item.content.is_null then
        node_text := dbms_xmldom.createTextNode(doc, node_value);
        child_node := dbms_xmldom.appendChild(node, dbms_xmldom.makeNode(node_text));
      end if;
    
    end case;
    
    
    return node;
  
  end;


  function get_child_json (
    node  in dbms_xmldom.DOMNode
  )
  return json_item
  is
    node_type  varchar2(30);
    node_ns    varchar2(2000);
    node_name  varchar2(4000);
    attr_list  dbms_xmldom.DOMNamedNodeMap;
    node_list  dbms_xmldom.DOMNodeList;
    item       json_item;
    obj        json_object_t;
    arr        json_array_t;
    output     json_item;   
    
  begin
        
    node_type := dbms_xmldom.getNodeType(node);
    
    case node_type
    when dbms_xmldom.ELEMENT_NODE then
      dbms_xmldom.getLocalName(node, node_name);
      dbms_xmldom.getNamespace(node, node_ns);
      
      if node_ns = NS_XPATH_FN then
      
        attr_list := dbms_xmldom.getAttributes(node);
        output.key := dbms_xmldom.getNodeValue(dbms_xmldom.getNamedItem(attr_list, 'key'));

        case node_name
        when 'map' then

          node_list := dbms_xmldom.getChildNodes(node);
          output.content := new json_object_t();
          
          if not dbms_xmldom.isNull(node_list) then
            obj := treat(output.content as json_object_t);    
            for i in 0 .. dbms_xmldom.getLength(node_list) - 1 loop          
              item := get_child_json(dbms_xmldom.item(node_list, i));
              if obj.has(item.key) then
                error(-20101, ERR_DUPLICATE_KEY, item.key);
              end if;
              if item.content is not null then
                obj.put(item.key, item.content);
              else
                case item.type_val
                when DBMS_JSON.TYPE_STRING then
                  obj.put(item.key, item.string_val);
                when DBMS_JSON.TYPE_NUMBER then
                  obj.put(item.key, item.number_val);
                when DBMS_JSON.TYPE_BOOLEAN then
                  obj.put(item.key, item.boolean_val);
                else
                  obj.put_null(item.key);
                end case;
              end if;       
            end loop;
            dbms_xmldom.freeNodeList(node_list);
          end if;
          
        when 'array' then
          
          node_list := dbms_xmldom.getChildNodes(node);
          output.content := new json_array_t();
          
          if not dbms_xmldom.isNull(node_list) then
            arr := treat(output.content as json_array_t);
            for i in 0 .. dbms_xmldom.getLength(node_list) - 1 loop          
              item := get_child_json(dbms_xmldom.item(node_list, i));
              if item.content is not null then
                arr.append(item.content);
              else
                case item.type_val
                when DBMS_JSON.TYPE_STRING then
                  arr.append(item.string_val);
                when DBMS_JSON.TYPE_NUMBER then
                  arr.append(item.number_val);
                when DBMS_JSON.TYPE_BOOLEAN then
                  arr.append(item.boolean_val);
                else
                  arr.append_null();
                end case;
              end if;        
            end loop;
            dbms_xmldom.freeNodeList(node_list);
          end if;
          
        when 'string' then
          
          output.type_val := DBMS_JSON.TYPE_STRING;
          output.string_val := dbms_xmldom.getNodeValue(dbms_xmldom.getFirstChild(node));
          
        when 'number' then
          
          output.type_val := DBMS_JSON.TYPE_NUMBER;
          output.number_val := to_number(dbms_xmldom.getNodeValue(dbms_xmldom.getFirstChild(node)));
          
        when 'boolean' then
          
          output.type_val := DBMS_JSON.TYPE_BOOLEAN;
          output.boolean_val := ( dbms_xmldom.getNodeValue(dbms_xmldom.getFirstChild(node)) = 'true' );
          
        when 'null' then
          
          output.type_val := DBMS_JSON.TYPE_NULL;
        
        else
          error(-20101, ERR_INVALID_XML_ELT, node_name, node_ns);
        end case;
      
      else
        error(-20101, ERR_INVALID_XML_ELT, node_name, node_ns);
      end if;
      
    else
      null;
    end case;
    
    dbms_xmldom.freeNode(node);
    
    return output;
  
  end;


  function json_to_xml (input in clob)
  return xmltype
  is
    doc     dbms_xmldom.DOMDocument;
    docnode dbms_xmldom.DOMNode;
    node    dbms_xmldom.DOMNode;
    item    json_item;
    output  xmltype;
  begin
    doc := dbms_xmldom.newDOMDocument();
    docnode := dbms_xmldom.makeNode(doc);
    item.content := json_element_t.parse(input);
    node := dbms_xmldom.appendChild(docnode, get_child_xml(doc, item));
    -- set default namespace declaration on the root element
    dbms_xmldom.setAttribute(dbms_xmldom.makeElement(node), 'xmlns', NS_XPATH_FN);
    output := dbms_xmldom.getxmltype(doc);
    dbms_xmldom.freeDocument(doc);
    return output;
  end;


  function xml_to_json (input in xmltype)
  return clob
  is
    doc     dbms_xmldom.DOMDocument;
    root    dbms_xmldom.DOMElement;
    output  json_item;
  begin
    doc := dbms_xmldom.newDOMDocument(input);
    root := dbms_xmldom.getDocumentElement(doc);
    output := get_child_json(dbms_xmldom.makeNode(root));
    dbms_xmldom.freeDocument(doc);
    return output.content.to_clob();
  exception
    when validation_error then
      error(-20100, 'FOJS0006: Invalid XML representation of JSON' || chr(10) || dbms_utility.format_error_stack);
  end;

end xutl_json;
/
