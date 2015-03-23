# Summary #

**ISManAll** supported by almost all OSMan objects by default. It used to retrieve object type and instance information.

# Interface #

  * **toString()** <br> Returns string representation of object instance. By default returns <b>ModuleName.ClassName.InstanceAddress</b>. <br><b>Example:</b>
<pre><code>var man=WScript.CreateObject("OSMan.Application");<br>
echo("App="+man.toString());<br>
</code></pre>
Should print:<br>
<pre><code>App=OSMan.Application.01718030<br>
</code></pre>
<ul><li><b>getClassName()</b> <br> Returns <a href='class_name.md'>short class name</a> (type) of object instance. <b>getClassName()</b> is only way to get object typeinfo used in OSMan. This method used in multitype methods like <b>IMap.putObject(obj)</b> to distinguish between different object types like <b>Node</b>, <b>Way</b> and <b>Relation</b>.</li></ul>

<h1>Usage</h1>
See <b>modlist.js</b> script in examples, <b>TAbstractMap.putObject</b> implementation in <b>uMap.pas</b> in OSman sources.