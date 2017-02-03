# Kat - Casper's Best Friend

Kat is a data driven interpreter on top of CasperJS. Rather than having to fire up a new project that includes Casper and PhantomJS each time, Kat is driven from a template and data set file. Separating data from implementation.

## **Dependancies:**
The following libraries and projects are utilized in Kat.

[Coffee-Script](http://coffeescript.org/) - JavaScript Transcompiler  
[jQuery](http://jquery.com/) - Improved DOM handling for JavaScript
[Lo-Dash](http://lodash.com/) - Functional programming support for JavaScript  
[Casper](http://casperjs.org/) - A navigation scripting & testing utility for PhantomJS  
[Phantom](http://phantomjs.org) - Scriptable Headless WebKit  

## Usage
Kat takes a [JSON](http://www.json.org/)/[YAML](http://www.yaml.org/) template file specified as an argument from the command line. The type of file is detected through the extension and does not need to be specified.

`kat --template="./data/templates/test.json"`

Currently the program will default to using four directories under *./data*.
- *./data/templates/* - primary configuration files to be used for testing
- *./data/logs/* - the result of those test
- *./data/screenshots/* - screen shots from the tests
- *./data/sets/* - sets of data to feed the templates 

## Config/Data File Formatting

**name** - name of the actual test that will be used for log the files.
**viewport** - size of the virtual browser in pixels.
**step** - a array/sequence of steps that comprises the actual meat of the test.

### Fully Qualified Data Format

Fully qualified objects have the parameter names called out as individual key/value pairs, generally starting with **name**.

```js
{
	"name": "Amazon Test 1",
	"viewport" : { "width": 1920, "height": 3840 },
	"step": [
		{"action": "open", "link": "http://www.amazon.com"},
		{"action": "type", "select": "#twotabsearchtextbox", "text": "functional javascript"},
		{"action": "click", "select": "input[class='nav-submit-input']"},
		{"action": "visible", "select": "h1#breadCrumb"},
		{"action": "capture", "select": "body"}]
}
```

### Short-hand for Steps

The above steps can be rewritten in shorthand as such.

#### Example of Short-hand (preferred format)
```js
	"step": [
		{"open": "http://www.amazon.com"},
		{"type": ["#twotabsearchtextbox", "functional javascript"]},
		{"click": "input[class='nav-submit-input']"},
		{"visible": "h1#breadCrumb"},
		{"capture": "body"}
  ]
```

### Actions

Each step is a list of objects and the properties must be distinct. This is important to remember for short-hand step syntax, because this disallows you from calling out multiple of the same action in a single step.

- **capture: [select, name, height, width]** - take a screen shot of particular selector.
- **casper: [func, args]** - evaluate and execute given function within the context of casper.
- **click: [select]** - click the particular selector element
- **disabled: [select, timeout]** - wait until the elements for a given selector are disabled.
- **download: [url, path, timeout]** - download specified url to local path.
- **echo: [message]** - print message out to console and in the log.
- **enabled: [select, timeout]** - wait until the elements for a given selector are enabled.
- **fill: [form, map]** - fill the form with the selector:value object pairs.
- **find: [select, timeout]** - wait until the element exists in the page
- **get: [key, select, attribute]** - get the attribute value of the specified selector and store it with the given key.
- **open: [url, user, password]** - open the link with authentication if provided.
- **run: [func, args, key]** - evaluate and execute the given function within the context of the client/browser.
- **set: [select, attribute, value]** - set a specified selector to a given value in the context of the client/browser.
- **text: [text, timeout]** - wait until the text is present in the page.
- **type: [select, text, modifiers]** - input text using key strokes with the text specified.
- **uri: [pattern, timeout]** - wait until the page is on the url to match the specified regular expression pattern.
- **visible: [select, timeout]** - wait until the element is visible on the page.
- **wait: [timeout]** - waits this many milliseconds.



The brackets can be omitted for actions with single arguments

#### Parameters

- ***args*** - an array of arguments applied to a given javascript function. (`["Five", 5]`)
- ***attribute*** - a attribute of a DOM element.(`"width"`)
- ***form*** - a [css selector](http://www.w3schools.com/cssref/css_selectors.asp) for a particular form. ( `"#form1"` )
- ***func*** - a javascript function to be evaluated. (`"function (a,b) { echo(a,b); }"`)
- ***key*** - name of the key to store a value. (`"search"`)
- ***map*** - key/value pair of [css selectors](http://www.w3schools.com/cssref/css_selectors.asp) and values.
&nbsp;&nbsp;&nbsp;&nbsp;(`{ "#street": "555 Happy Street", "#city": "Austin", "#state": "Texas", "#zip": "55555" }`)
- ***message*** - text to print to console and log. (`"echo this"`)
- ***modifiers*** - alt, control, shift, etc. (`"ctrl+alt+shift"`)
- ***name*** - part of the name used in creating a screen shot file. (`"my capture"`)
- ***password*** - a password for a particular user. (`"love"`)
- ***path*** - a local file path. (`"/tmp/file.png"`)
- ***pattern*** - a [regular expression](http://www.regular-expressions.info/). (`"http://www\.google\.com"`)
- ***select*** - a [CSS Selector](http://www.w3schools.com/cssref/css_selectors.asp) for an elment or elements. (`"input[class='something']"`)
- ***text*** - literal text to be typed key by key or searched. (`"Looking for this"`)
- ***timeout*** - milliseconds to wait. (`5000`)
- ***url*** - a url. (`"http://www.amazon.com"`)
- ***user*** - a user name. (`"bob"`)
- ***value*** - literal value or text to match. (`"a string"`)

## Data Sets
A data set a is a list of maps that correspond to information that the test can use during run-time. Data sets can be in  [JSON](http://www.json.org/), [YAML](http://www.yaml.org/), [Tab delimited](http://en.wikipedia.org/wiki/Tab-separated_values), or [Comma delimited](http://en.wikipedia.org/wiki/Comma-separated_values). Comma, and Tab separated value files support both horizontal and vertical configurations.

`kat --template="./data/templates/test-template.json --set="./data/sets/test-set.tsv`

Data Sets drive test execution. All tests specified within the configuration file will be ran for every map in the set. The set below will echo `echoThis` twice.

**Data Set file**

```js
//JSON configuration - *.json  
[
	{ "echoThis" : "Output this during test", "unusedKey": "This wont be used"},
	{ "echoThis" : "Also Output this during test", "unusedKey": "neither will this"}
]

//Vertical configuration - *.csv, *.tsv  
echoThis,Output this during test,Also Output this during test.
unusedKey,This wont be used, neither will this.

or  

//Horizontal configration - *.comma, *.tab
echoThis,unusedKey
Output this during test,This wont be used
Also Output this during test,neith will this

```  

**Configuration File**
```javascript
{
	"name": "Data Set Test"
	"step": [
		{"echo": "${echoThis}"}
	]
}
```

## Notes and Copyright

---

> Kat is a work in progress. If you have any questions, problems, or ideas you are more than welcome to contact me.

---

<<<<<<< HEAD
*Copyright (c) 2014 __Kephren Newton__ <kephren.newton@gmail.com>, __BSD Licensed__*
=======
## License

The MIT License (MIT)

Copyright (c) 2015 Kephren Newton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
>>>>>>> 1c2127a892a2ecc782b1f88475c3333bcec47f16
