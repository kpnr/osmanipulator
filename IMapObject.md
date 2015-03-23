# Summary #

**IMapObject** supported by all OSM map objects - [Node](INode.md), [Way](IWay.md), [Relation](IRelation.md). It used to store common properties like _id_, _version_, _timestamp_.

# Interface #
  * Base interface is [IOSManAll](IOSManAll.md).
  * **id** <br> OSM object identifier <b>id</b>. In scripting enviroment it can be autoconverted from <i>Int64</i> into <i>DoublePrecision</i>, so only 53 bit <b>id</b> fully supproted. <b>id</b> is <b>0</b> by default.<br>
<ul><li><b>changeset</b> <br> Last committed <i>changeset</i>. In scripting enviroment it can be autoconverted from <i>Int64</i> into <i>DoublePrecision</i>, so only 53 bit <b>changeset</b> fully suppoted. <b>changeset</b> is <b>0</b> by default.<br>
</li><li><b>version</b> <br> OSM object version. It is 32-bit <i>Integer</i>. It is <b>0</b> by default.<br>
</li><li><b>userId</b> <br> Last editor <i>userId</i>. It is 32-bit <i>Integer</i>. It is <b>0</b> by default.<br>
</li><li><b>userName</b> <br> Last editor <i>userName</i>. It is <i>String</i>. It is empty string by default.<br>
</li><li><b>timestamp</b> <br> OSM object timestamp. It is <i>String</i>. Format "yyyy-mm-ddThh:nn:ssZ" like in OSM files.<br>
</li><li><b>tags</b> <br> optional object tags like <i>highway=seconadry</i>, etc. This property supports <a href='IKeyList.md'>IKeyList</a> interface.</li></ul>

<h1>Usage</h1>
All this properties are read-write, so you can examine and modify it as needed. <br> <b>Example:</b>
<pre><code> //modify existing node<br>
 node.version=node.version+1;<br>
 node.userId=123;<br>
 node.userName='Adam';<br>
</code></pre>