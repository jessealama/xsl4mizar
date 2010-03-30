<?xml version='1.0' encoding='UTF-8'?>

<xsl:stylesheet version="1.0" extension-element-prefixes="dc" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns="http://www.w3.org/1999/xhtml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml"/>
  <xsl:output doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>
  <xsl:output doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
  <xsl:output omit-xml-declaration="no"/>
  <!-- $Revision: 1.8 $ -->
  <!--  -->
  <!-- File: mhtml_main.xsltxt - html-ization of Mizar XML, main file -->
  <!--  -->
  <!-- Author: Josef Urban -->
  <!--  -->
  <!-- License: GPL (GNU GENERAL PUBLIC LICENSE) -->
  <!-- XSLTXT (https://xsltxt.dev.java.net/) stylesheet taking -->
  <!-- XML terms, formulas and types to less verbose format. -->
  <!-- To produce standard XSLT from this do e.g.: -->
  <!-- java -jar xsltxt.jar toXSL miz.xsltxt | sed -e 's/<!\-\- *\(<\/*xsl:document.*\) *\-\->/\1/g' >miz.xsl -->
  <!-- (the sed hack is there because xsl:document is not yet supported by xsltxtx) -->
  <!-- Then e.g.: xsltproc miz.xsl ordinal2.pre >ordinal2.pre1 -->
  <!-- TODO: number B vars in fraenkel - done since 1.72 -->
  <!-- handle F and H parenthesis as K parenthesis -->
  <!-- article numbering in Ref? -->
  <!-- absolute definiens numbers for thesisExpansions? - done -->
  <!-- do not display BlockThesis for Proof? - done, should but should be optional for Now -->
  <!-- add @nr to canceled -->
  <!-- Constructor should know its serial number! - needed in defs -->
  <!-- possibly also article? -->
  <!-- change globally 'G' to 'L' for types? -> then change the -->
  <!-- hacks here and in emacs.el -->
  <!-- display definiens? - done -->
  <!-- NOTES: constructor disambiguation is done using the absolute numbers -->
  <!-- (attribute 'nr' and 'aid' of the Constructor element. -->
  <!-- This info for Constructors not defined in the article is -->
  <!-- taken from the .atr file (see variable $constrs) -->
  <xsl:include href="mhtml_block_top.xsl"/>

  <!-- ##INCLUDE HERE -->
  <!-- Default -->
  <xsl:template match="/">
    <xsl:choose>
      <xsl:when test="$generate_items = &quot;1&quot;">
        <xsl:apply-templates select="/*/JustifiedTheorem|/*/DefTheorem|/*/SchemeBlock"/>
        <xsl:apply-templates select="//RCluster|//CCluster|//FCluster|//Definition|//IdentifyWithExp"/>
        <!-- top-level lemmas -->
        <xsl:for-each select="/*/Proposition">
          <xsl:document href="proofhtml/lemma/{$anamelc}.{@propnr}" format="html"> 
          <xsl:apply-templates select="."/>
          </xsl:document> 
          <xsl:variable name="bogus" select="1"/>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="$body_only = &quot;0&quot;">
            <xsl:element name="html">
              <xsl:element name="head">
                <!-- output the css defaults for div and p (for indenting) -->
                <xsl:element name="link">
                  <xsl:attribute name="rel">
                    <xsl:text>stylesheet</xsl:text>
                  </xsl:attribute>
                  <xsl:attribute name="href">
                    <xsl:text>article.css</xsl:text>
                  </xsl:attribute>
                </xsl:element>
                <xsl:element name="title">
                  <xsl:choose>
                    <xsl:when test="$mk_header &gt; 0">
                      <xsl:value-of select="$aname"/>
                      <xsl:text>: </xsl:text>
                      <xsl:for-each select="document($hdr,/)/Header/dc:title">
                        <xsl:value-of select="text()"/>
                      </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="$aname"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:element>
                <xsl:element name="script">
                  <xsl:attribute name="type">
                    <xsl:text>text/javascript</xsl:text>
                  </xsl:attribute>
                  <xsl:attribute name="src">
                    <xsl:text>article.js</xsl:text>
                  </xsl:attribute>
                </xsl:element>
                <xsl:element name="base">
                  <xsl:attribute name="target">
                    <xsl:value-of select="$default_target"/>
                  </xsl:attribute>
                </xsl:element>
              </xsl:element>
              <xsl:element name="body">
                <xsl:if test="$wiki_links=1">
                  <xsl:element name="div">
                    <xsl:attribute name="class">
                      <xsl:text>wikiactions</xsl:text>
                    </xsl:attribute>
                    <xsl:element name="ul">
                      <xsl:element name="li">
                        <xsl:element name="a">
                          <xsl:attribute name="href">
                            <xsl:value-of select="concat($lmwikicgi,&quot;?p=&quot;,$lgitproject,&quot;;a=edit;f=mml/&quot;,$anamelc,&quot;.miz&quot;)"/>
                          </xsl:attribute>
                          <xsl:attribute name="rel">
                            <xsl:text>nofollow</xsl:text>
                          </xsl:attribute>
                          <xsl:text>Edit</xsl:text>
                        </xsl:element>
                      </xsl:element>
                      <xsl:element name="li">
                        <xsl:element name="a">
                          <xsl:attribute name="href">
                            <xsl:value-of select="concat($lgitwebcgi,&quot;?p=&quot;,$lgitproject,&quot;;a=history;f=mml/&quot;,$anamelc,&quot;.miz&quot;)"/>
                          </xsl:attribute>
                          <xsl:text>History</xsl:text>
                        </xsl:element>
                      </xsl:element>
                      <xsl:element name="li">
                        <xsl:element name="a">
                          <xsl:attribute name="href">
                            <xsl:value-of select="concat($lgitwebcgi,&quot;?p=&quot;,$lgitproject,&quot;;a=blob_plain;f=mml/&quot;,$anamelc,&quot;.miz&quot;)"/>
                          </xsl:attribute>
                          <xsl:attribute name="rel">
                            <xsl:text>nofollow</xsl:text>
                          </xsl:attribute>
                          <xsl:text>Raw</xsl:text>
                        </xsl:element>
                      </xsl:element>
                      <xsl:element name="li">
                        <xsl:element name="a">
                          <xsl:attribute name="href">
                            <xsl:value-of select="concat(&quot;../discussion/&quot;,$anamelc, &quot;.html&quot;)"/>
                          </xsl:attribute>
                          <xsl:text>Discussion</xsl:text>
                        </xsl:element>
                      </xsl:element>
                      <xsl:element name="li">
                        <xsl:element name="a">
                          <xsl:attribute name="href">
                            <xsl:text>../index.html</xsl:text>
                          </xsl:attribute>
                          <xsl:text>Index</xsl:text>
                        </xsl:element>
                      </xsl:element>
                      <xsl:element name="li">
                        <xsl:element name="a">
                          <xsl:attribute name="href">
                            <xsl:value-of select="concat($lgitwebcgi,&quot;?p=&quot;,$lgitproject)"/>
                          </xsl:attribute>
                          <xsl:text>Gitweb</xsl:text>
                        </xsl:element>
                      </xsl:element>
                    </xsl:element>
                  </xsl:element>
                </xsl:if>
                <xsl:if test="$mk_header &gt; 0">
                  <xsl:apply-templates select="document($hdr,/)/Header/*"/>
                  <xsl:element name="br"/>
                </xsl:if>
                <!-- first read the keys for imported stuff -->
                <!-- apply[document($constrs,/)/Constructors/Constructor]; -->
                <!-- apply[document($thms,/)/Theorems/Theorem]; -->
                <!-- apply[document($schms,/)/Schemes/Scheme]; -->
                <!-- then process the whole document -->
                <xsl:apply-templates/>
              </xsl:element>
            </xsl:element>
          </xsl:when>
          <!-- $body_only > 0 -->
          <xsl:otherwise>
            <xsl:if test="$mk_header &gt; 0">
              <xsl:apply-templates select="document($hdr,/)/Header/*"/>
              <xsl:element name="br"/>
            </xsl:if>
            <xsl:apply-templates/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- tpl [*] { copy { apply [@*]; apply; } } -->
  <!-- tpl [@*] { copy-of `.`; } -->
  <!-- Header rules -->
  <xsl:template match="dc:title">
    <xsl:call-template name="pcomment">
      <xsl:with-param name="str" select="text()"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="dc:creator">
    <xsl:call-template name="pcomment">
      <xsl:with-param name="str" select="concat(&quot;by &quot;, text())"/>
    </xsl:call-template>
    <xsl:call-template name="pcomment">
      <xsl:with-param name="str">
        <xsl:text/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="dc:date">
    <xsl:call-template name="pcomment">
      <xsl:with-param name="str" select="concat(&quot;Received &quot;, text())"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="dc:rights">
    <xsl:call-template name="pcomment">
      <xsl:with-param name="str" select="concat(&quot;Copyright &quot;, text())"/>
    </xsl:call-template>
  </xsl:template>
</xsl:stylesheet>
