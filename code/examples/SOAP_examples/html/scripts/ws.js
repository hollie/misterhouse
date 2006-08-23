/******************************************************************************/
var WS = {
  Version :   '0.1',
  Author :    'James M Snell',
  Copyright : 'Copyright 2005, IBM Corporation',
  Revision :  '2005-09-29T18:00:00-7:00'
};

/******************************************************************************/
Function.prototype.bind2 = function(object) {
  var __method = this;
  return function() {
    return __method.apply(object, arguments);
  }
}

/******************************************************************************/
Array.prototype.each = function(method) {
  for (var n = 0; n < this.length; n++) {
    try {
      method(this[n]);
    } catch(e) {}
  }
}

/******************************************************************************/
var XML = {
  createDocumentQName : function(qname) {
    return XML.createDocument(qname.namespace,qname.value_of());
  },
  createDocument : function(namespace,nodename) {
    return Try.these(
      function() {
        var doc = new ActiveXObject('Msxml2.XMLDOM');
        var root = XML.createElementNS(doc, nodename, namespace);
        doc.documentElement = root;
        return doc;
      },
      function() {
        var doc = new ActiveXObject('Microsoft.XMLDOM')
        var root = XML.createElementNS(doc, nodename, namespace);
        doc.documentElement = root;
        return doc;
      },
      function() {
        return document.implementation.createDocument(
        namespace,
        nodename,
        null)
      }
    ) || false;
  },
  createElementNS : function(document,nodename,namespace) {      
   	var el = Try.these(
      function() {
        var el = null;
        if (namespace) {
          el = document.createNode(1,nodename,namespace);
        } else {
          el = document.createNode(1,nodename,"");
        }
        return el;
     },
     function() {
       var el = null;
       if (namespace) {
         el = document.createElementNS(namespace,nodename);
       } else {
         el = document.createElement(nodename);
       }
       return el;
       }
     ) || false;
   return el;
  },
  createElementQName : function(document,qname) {
    return XML.createElementNS(document,qname.value_of(),qname.namespace);
  },
  createAttributeNS : function(document,nodename,namespace,value) {
    var attr = Try.these(
      function() { return document.createNode(2,nodename,namespace)},
      function() { return document.createAttributeNS(namespace,nodename)}
    ) || false;
    attr.nodeValue = value;
    return attr;
  },
  createAttributeQName : function(document,qname,value) {
    return XML.createAttributeNS(document,qname.value_of(),qname.namespace,value);
  },
  createAttribute : function(document,nodename,value) {
    var attr = Try.these(
      function() { return document.createNode(2, nodename)},
      function() { return document.createAttribute(nodename)}
    ) || false;
    attr.nodeValue = value;
    return attr;
  },
  createText : function(document,value) {
    var node = Try.these(
      function() { return document.createTextNode(value) }
    ) || false;
    return node;
  },
  createCDATA : function(document,value) {
    var node = Try.these(
      function() { return document.createCDATASection(value) }
    ) || false;
    return node;
  },
  getElementsByQName : function(element, qname) {
    var nl = null;
    if(!element.getElementsByTagNameNS) {
      nl = new Array();
      var nodes = element.getElementsByTagName(qname.value_of());
      for (var n = 0; n < nodes.length; n++) {
        if (nodes[n].namespaceURI == qname.namespace) {
          nl.push(nodes[n]);
        }
      }
    } else {
      nl = element.getElementsByTagNameNS(qname.namespace,qname.localpart);
    }
    return nl;
  }
}
    
/******************************************************************************/
WS.QName = Class.create();
WS.QName.fromElement = function() {
  var qname =
    new WS.QName(
      (this.baseName)?this.baseName:this.localName,
      this.namespaceURI,
      this.prefix
    );
  return qname;
}
WS.QName.prototype = {
  initialize : function(localpart) {
    this.localpart = localpart;
    if (arguments[1]) this.namespace = arguments[1];
    if (arguments[2]) this.prefix = arguments[2];
  },
  to_string : function() {
    return (this.namespace) ? 
      '{' + this.namespace + '}' + this.localpart : 
        this.localpart;
  },
  value_of : function() {
    return ((this.prefix)?this.prefix + ':':'') + this.localpart;
  },
  equals : function(obj) {
    return (obj instanceof WS.QName &&
            obj.localpart == this.localpart &&
            obj.namespace == this.namespace);
  }
};

/******************************************************************************/
var SOAP = {
  Version : '1.1',
  URI : 'http://schemas.xmlsoap.org/soap/envelope/',
  XSI : 'http://www.w3.org/2000/10/XMLSchema-instance',
  XSIQNAME : new WS.QName(
    'type',
    'http://www.w3.org/2000/10/XMLSchema-instance','xsi'),
  XSINIL : new WS.QName(
    'nil',
    'http://www.w3.org/2000/10/XMLSchema-instance','xsi'),
  SOAPENCODING : 'http://schemas.xmlsoap.org/soap/encoding/',
  NOENCODING : null,
  ENCODINGSTYLE : new WS.QName(
    'encodingStyle',
    'http://schemas.xmlsoap.org/soap/envelope/','s')
};

/******************************************************************************/
SOAP.Element = Class.create();
SOAP.Element.prototype = {
  initialize : function() {
    if (arguments[0]) this.initialize_internal(arguments[0]);
  },
  initialize_internal : function(element) {
    this.element = element;
  },
  asElement : function() {
    return this.element;
  },
  qname : function() {
    return WS.QName.fromElement.bind2(this.element)();
  },
  set_encoding_style : function(style) {
    this.set_attribute(SOAP.ENCODINGSTYLE,style);
  },
  set_attribute : function(qname, value) {
    var attr = XML.createAttributeQName(
      this.element.ownerDocument, 
      qname, 
      value);
    if (this.element.setAttributeNodeNS) {
      this.element.setAttributeNodeNS(attr);
    } else {
      this.element.setAttributeNode(attr);
    }
  },
  get_attribute : function(qname) {
    var val = null;
    for (var n = 0; n < this.element.attributes.length; n++) {
      var attr = this.element.attributes[n];
      if (qname.equals(WS.QName.fromElement.bind2(attr)())) {
        val = attr.nodeValue;
        break;
      }
    }
    return val;
  },
  has_attribute : function(qname) {
    var val = null;
    for (var n = 0; n < this.element.attributes.length; n++) {
      var attr = this.element.attributes[n];
      if (qname.equals(WS.QName.fromElement.bind2(attr)())) {
        val = true;
        break;
      }
    }
    return val;
  },
  set_value : function(value, usecdata) {
    var doc = this.element.ownerDocument;
    if (usecdata) {
      this.element.appendChild(XML.createCDATA(doc,value));
    } else {
      this.element.appendChild(XML.createText(doc,value));
    }
  },
  get_value : function() {
    return this.element.firstChild.nodeValue;
  },
  create_child : function(qname) {
    var doc = this.element.ownerDocument;
    var el = XML.createElementQName(doc, qname);
    this.element.appendChild(el);
    var ret = new SOAP.Element(el);
    return ret;
  },
  get_children : function(qname) {
    var nodes = XML.getElementsByQName(this.element,qname);
    var childnodes = new Array();
    for (var n = 0; n < nodes.length; n++) {
      childnodes.push(new SOAP.Element(nodes[n]));
    }
    return childnodes;
  },
  get_all_children : function() {
    var nodes = this.element.childNodes;
    var childnodes = new Array();
    for (var n = 0; n < nodes.length; n++) {
      if (nodes[n].nodeType == 1) {
        childnodes.push(new SOAP.Element(nodes[n]));
      }
    }
    return childnodes;
  },
  get_binder : function() {
    return WS.Binder.get_for_qname(this.qname());
  }
};



/******************************************************************************/
SOAP.Envelope = Class.create();
SOAP.Envelope.QNAME = new WS.QName('Envelope',SOAP.URI);
SOAP.Envelope.prototype = (new SOAP.Element()).extend({
  initialize : function() {
    var element = arguments[0];
    if (!element) {
      var document = 
        XML.createDocumentQName(SOAP.Envelope.QNAME);
      element = document.documentElement;
    }
    this.initialize_internal(element);
  },
  set_value : null,
  get_value : null,
  create_child : null,
  create_header : function() {
    if (!this.has_header()) {
      var doc = this.element.ownerDocument;
      var el = XML.createElementQName(doc, SOAP.Header.QNAME);
      if (this.element.firstChild) {
        this.element.insertBefore(el, this.element.firstChild);
      } else {
        this.element.appendChild(el);
      }
      var ret = new SOAP.Header(el);
      return ret;
    } else {
      return this.get_header();
    }
  },
  get_header : function() {
    var val = null;
    for (var n = 0; n < this.element.childNodes.length; n++) {
      if (this.element.childNodes[n].nodeType == 1) {
        var el = this.element.childNodes[n];
        if (SOAP.Header.QNAME.equals(WS.QName.fromElement.bind2(el)())) {
          val = new SOAP.Header(el);
          break;
        }
      }
    }
    return val;
  },
  has_header : function() {
    var val = null;
    for (var n = 0; n < this.element.childNodes.length; n++) {
      if (this.element.childNodes[n].nodeType == 1) {
        var el = this.element.childNodes[n];
        if (SOAP.Header.QNAME.equals(WS.QName.fromElement.bind2(el)())) {
          val = true;
          break;
        }
      }
    }
    return val;
  },
  create_body : function() {
    if (!this.has_body()) {
      var doc = this.element.ownerDocument;
      var el = XML.createElementQName(doc, SOAP.Body.QNAME);
      this.element.appendChild(el);
      var ret = new SOAP.Body(el);
      return ret;
    } else {
      return this.get_body();
    }
  },
  get_body : function() {
    var val = null;
    for (var n = 0; n < this.element.childNodes.length; n++) {
      if (this.element.childNodes[n].nodeType == 1) {
        var el = this.element.childNodes[n];
        if (SOAP.Body.QNAME.equals(WS.QName.fromElement.bind2(el)())) {
          val = new SOAP.Body(el);
          break;
        }
      }
    }
    return val;
  },
  has_body : function() {
    var val = null;
    for (var n = 0; n < this.element.childNodes.length; n++) {
      if (this.element.childNodes[n].nodeType == 1) {
        var el = this.element.childNodes[n];
        if (SOAP.Body.QNAME.equals(WS.QName.fromElement.bind2(el)())) {
          val = true;
          break;
        }
      }
    }
    return val;
  }
});


/******************************************************************************/
SOAP.Header = Class.create();
SOAP.Header.QNAME = new WS.QName('Header',SOAP.URI);
SOAP.Header.prototype = (new SOAP.Element()).extend({
  initialize : function(element) {
    this.initialize_internal(element);
  },
  set_value : function() {},
  get_value : function() {}
});


/******************************************************************************/
SOAP.Body = Class.create();
SOAP.Body.QNAME = new WS.QName('Body',SOAP.URI);
SOAP.Body.prototype = (new SOAP.Element()).extend({
  initialize : function(element) {
    this.initialize_internal(element);
  },
  set_value : function() {},
  get_value : function() {},
  set_rpc : function(method, params, encodingstyle) {
    var child = this.create_child(method);
    if (encodingstyle) {
      child.set_encoding_style(encodingstyle);
    }
    for (var n = 0; n < params.length; n++) {
      var param = params[n];
      var pchild = null;
      if (param.name instanceof WS.QName) {
        pchild = child.create_child(param.name);
      } else {
        pchild = 
          child.create_child(
            new WS.QName(param.name,method.namespace,method.prefix)
          );
      }
      if (param.value) {
        pchild.set_value(param.value);
      } else {
        pchild.set_attribute(SOAP.XSINIL,'true');
      }
      if (param.xsitype) {
        pchild.set_attribute(SOAP.XSIQNAME,param.xsitype.value_of());
      }
      if (param.encodingstyle) {
        pchild.set_encoding_style(param.encodingstyle);
      }
    }
  }
});


/******************************************************************************/
WS.Handler = Class.create();
WS.Handler.prototype = {
  initialize : function() {},
  on_request : function(call, envelope) {},
  on_response : function(call, envelope) {},
  on_error : function(call, envelope) {}
};

/******************************************************************************/
WS.Binder = Class.create();
WS.Binder.register = function(qname,type,binder) {
  if (!WS.Binder.binders) WS.Binder.binders = new Array();
  WS.Binder.binders.push({qname:qname,type:type,binder:binder});
}
WS.Binder.get_for_qname = function(qname) {
  if (!WS.Binder.binders) return null;
  var binder = null;
  for (var n = 0; n < this.binders.length; n++) {
    var b = this.binders[n];
    if (b.qname.equals(qname)) {
      binder = b.binder;
      break;
    }
  }
  return binder;
}
WS.Binder.get_for_type = function(type) {
  if (!WS.Binder.binders) return null;
  var binder = null;
  for (var n = 0; n < this.binders.length; n++) {
    var b = this.binders[n];
    if (b.type == type) {
      binder = b.binder;
      break;
    }
  }
  return binder;
}
WS.Binder.prototype = {
  initialize : function() {},
  to_soap_element : function(value_object,envelope) {},
  to_value_object : function(soap_element) {}
};


/******************************************************************************/
WS.Call = Class.create();
WS.Call.InvokeHandlers = function(call, envelope, transport, state) {
  this.each(
    function(value) {
      switch(state) {
        case 'request':
          try {
            value.on_request(call,envelope, transport);
          } catch(e) {}
          break;
        case 'response':
          try {
            value.on_response(call,envelope, transport);
          } catch(e) {}
          break;
        case 'error':
          try {
            value.on_error(call,envelope,transport);
          } catch(e) {}
          break;
      }
    }
  );
}
WS.Call.prototype = {
  initialize : function(uri) {
    this.uri = uri;
    this.handlers = new Array();
    this.invokeHandlers = WS.Call.InvokeHandlers.bind(this.handlers);
  },
  add_handler : function(handler) {
    this.handlers.push(handler);
  },
  invoke_rpc : function(qname, params, encodingstyle, callback) {
    var env = new SOAP.Envelope();
    env.create_body().set_rpc(qname,params,encodingstyle);
    this.invoke(env, callback);
  },
  invoke : function(envelope, callback) {
    this.invokeHandlers(this,envelope,null,'request');
    var call = this;
    var options = {};
    options.postBody = envelope.asElement().ownerDocument;
    options.onComplete = 
      function(transport) {
        try {
          var xml = transport.responseXML;
          if (xml) {
            var responseEnv = new SOAP.Envelope(xml.documentElement);
            call.invokeHandlers(call,responseEnv,transport, 'response');
            callback(this, responseEnv, transport.responseText);
          } else {
            call.invokeHandlers(call,null,'error');
          }
        } catch(e) {
          call.invokeHandlers(call,e,'error');
        }
      };
    options.requestHeaders = new Array();
    options.requestHeaders.push('Content-Type');
    options.requestHeaders.push('text/xml');
    if (this.soapAction) {
      options.requestHeaders.push('SOAPAction');
      options.requestHeaders.push('"' + this.soapAction + '"');
    } else {
      options.requestHeaders.push('SOAPAction');
      options.requestHeaders.push('""');
    }
    
    new Ajax.Request(this.uri,options);
  }
};
