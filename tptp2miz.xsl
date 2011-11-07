<?xml version='1.0' encoding='UTF-8'?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text"/>
  <xsl:strip-space elements="*"/>
  <!-- //////////////////////////////////////////////////////////////////// -->
  <!-- Stylesheet parameters -->
  <!-- //////////////////////////////////////////////////////////////////// -->
  <xsl:param name="article">
    <xsl:text/>
  </xsl:param>
  <!-- //////////////////////////////////////////////////////////////////// -->
  <!-- Utilities -->
  <!-- //////////////////////////////////////////////////////////////////// -->
  <xsl:variable name="lcletters">
    <xsl:text>abcdefghijklmnopqrstuvwxyz</xsl:text>
  </xsl:variable>
  <xsl:variable name="ucletters">
    <xsl:text>ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:text>
  </xsl:variable>

  <xsl:template name="lc">
    <xsl:param name="s"/>
    <xsl:value-of select="translate($s, $ucletters, $lcletters)"/>
  </xsl:template>

  <xsl:template name="uc">
    <xsl:param name="s"/>
    <xsl:value-of select="translate($s, $lcletters, $ucletters)"/>
  </xsl:template>

  <xsl:template name="capitalize-after-understore">
    <xsl:param name="string"/>
    <xsl:choose>
      <xsl:when test="contains ($string, &quot;_&quot;)">
        <xsl:variable name="before" select="substring-before ($string, &quot;_&quot;)"/>
        <xsl:variable name="after" select="substring-after ($string, &quot;_&quot;)"/>
        <xsl:choose>
          <xsl:when test="$after = &quot;&quot;">
            <xsl:value-of select="$before"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable name="after-length" select="string-length ($after)"/>
            <xsl:variable name="first-char-as-string" select="substring ($after, 1, 1)"/>
            <xsl:variable name="after-first-char" select="substring ($after, 2, $after-length)"/>
            <xsl:variable name="first-char-as-string-uc">
              <xsl:call-template name="uc">
                <xsl:with-param name="s" select="$first-char-as-string"/>
              </xsl:call-template>
            </xsl:variable>
            <xsl:variable name="transformed-tail">
              <xsl:call-template name="capitalize-after-understore">
                <xsl:with-param name="string" select="$after-first-char"/>
              </xsl:call-template>
            </xsl:variable>
            <xsl:value-of select="concat ($before, $first-char-as-string-uc, $transformed-tail)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$string"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="/">
    <xsl:choose>
      <xsl:when test="not(tstp)">
        <xsl:message terminate="yes">
          <xsl:text>Error: this does not appear to be a TSTP XML document, because it lacks a &apos;tstp&apos; root element.</xsl:text>
        </xsl:message>
      </xsl:when>
      <xsl:when test="tstp[2]">
        <xsl:message terminate="yes">
          <xsl:text>Error: this does not appear to be a TSTP XML document, because it has multiple &apos;tstp&apos; root elements.</xsl:text>
        </xsl:message>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="tstp"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tstp">
    <xsl:text>environ</xsl:text>
    <xsl:text>
</xsl:text>
    <xsl:if test="not($article = &quot;&quot;)">
      <xsl:variable name="article-uc">
        <xsl:call-template name="uc">
          <xsl:with-param name="s" select="$article"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:text>
</xsl:text>
      <xsl:text>vocabularies </xsl:text>
      <xsl:value-of select="$article-uc"/>
      <xsl:text>;</xsl:text>
      <xsl:text>
</xsl:text>
      <xsl:text>notations </xsl:text>
      <xsl:value-of select="$article-uc"/>
      <xsl:text>;</xsl:text>
      <xsl:text>
</xsl:text>
      <xsl:text>constructors </xsl:text>
      <xsl:value-of select="$article-uc"/>
      <xsl:text>;</xsl:text>
      <xsl:text>
</xsl:text>
    </xsl:if>
    <xsl:text>
</xsl:text>
    <xsl:text>begin</xsl:text>
    <xsl:text>
</xsl:text>
    <xsl:if test="descendant::variable">
      <xsl:text>
</xsl:text>
    </xsl:if>
    <!-- give the type 'set' to all variables appearing in the problem -->
    <xsl:for-each select="descendant::variable[@name
                                 and not(@name = preceding::variable[@name]/@name)]">
      <xsl:apply-templates select="." mode="set"/>
    </xsl:for-each>
    <xsl:if test="descendant::variable">
      <xsl:text>
</xsl:text>
    </xsl:if>
    <xsl:for-each select="formula">
      <xsl:apply-templates select="."/>
      <xsl:text>
</xsl:text>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="comment"/>

  <xsl:template match="formula[not(@name)]">
    <xsl:message terminate="yes">
      <xsl:text>We encountered a formula element that lacks a name attribute.</xsl:text>
    </xsl:message>
  </xsl:template>

  <xsl:template match="formula[@name]">
    <xsl:variable name="safe-name">
      <xsl:call-template name="capitalize-after-understore">
        <xsl:with-param name="string" select="@name"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:value-of select="$safe-name"/>
    <xsl:text>:</xsl:text>
    <xsl:text>
</xsl:text>
    <xsl:apply-templates select="*[1]"/>
    <xsl:text>;</xsl:text>
    <xsl:text>
</xsl:text>
  </xsl:template>

  <xsl:template match="variable[not(@name)]">
    <xsl:message terminate="yes">
      <xsl:text>Error: unable to render a variable element that lacks a name attribute.</xsl:text>
    </xsl:message>
  </xsl:template>

  <xsl:template match="variable[@name]">
    <xsl:value-of select="@name"/>
  </xsl:template>

  <xsl:template match="variable[not(@name)]" mode="set">
    <xsl:message terminate="yes">
      <xsl:text>Error: unable to assign the type &apos;set&apos; to a variable that lacks a name</xsl:text>
    </xsl:message>
  </xsl:template>

  <xsl:template match="variable[@name]" mode="set">
    <xsl:text>reserve </xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text> for set;
</xsl:text>
  </xsl:template>

  <xsl:template match="quantifier[not(@type)]">
    <xsl:message terminate="yes">
      <xsl:text>Error: we encountered a quantifier element that lacks a type attribute.</xsl:text>
    </xsl:message>
  </xsl:template>

  <xsl:template match="quantifier[@type and not(@type = &quot;universal&quot; or @type = &quot;existential&quot;)]">
    <xsl:variable name="type" select="@type"/>
    <xsl:variable name="message" select="concat (&quot;Error: we encountered a quantifier element whose type, &apos;&quot;, $type, &quot;&apos; is neither &apos;universal&apos; nor &apos;existential&apos;, which are the only two types we handle.&quot;)"/>
    <xsl:message terminate="yes">
      <xsl:value-of select="$message"/>
    </xsl:message>
  </xsl:template>

  <xsl:template match="quantifier[@type = &quot;existential&quot;]">
    <xsl:text>ex </xsl:text>
    <xsl:call-template name="ilist">
      <xsl:with-param name="separ">
        <xsl:text>,</xsl:text>
      </xsl:with-param>
      <xsl:with-param name="elems" select="variable"/>
    </xsl:call-template>
    <xsl:text> st </xsl:text>
    <xsl:apply-templates select="*[position() = last()]"/>
  </xsl:template>

  <xsl:template match="quantifier[@type = &quot;universal&quot; and implication]">
    <xsl:text>for </xsl:text>
    <xsl:call-template name="ilist">
      <xsl:with-param name="separ">
        <xsl:text>,</xsl:text>
      </xsl:with-param>
      <xsl:with-param name="elems" select="variable"/>
    </xsl:call-template>
    <xsl:text> st </xsl:text>
    <xsl:apply-templates select="implication/*[1]"/>
    <xsl:text> holds </xsl:text>
    <xsl:apply-templates select="implication/*[2]"/>
  </xsl:template>

  <xsl:template match="quantifier[@type = &quot;universal&quot; and not(implication)]">
    <xsl:text>for </xsl:text>
    <xsl:call-template name="ilist">
      <xsl:with-param name="separ">
        <xsl:text>,</xsl:text>
      </xsl:with-param>
      <xsl:with-param name="elems" select="variable"/>
    </xsl:call-template>
    <xsl:text> holds </xsl:text>
    <xsl:apply-templates select="*[position() = last()]"/>
  </xsl:template>

  <xsl:template match="negation|">
    <xsl:text>not </xsl:text>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="function[not(@name)]">
    <xsl:message terminate="yes">
      <xsl:text>Error: we cannot render a function element that lacks a name.</xsl:text>
    </xsl:message>
  </xsl:template>

  <xsl:template match="predicate[not(@name)]">
    <xsl:message terminate="yes">
      <xsl:text>Error: we cannot render a predicate element that lacks a name.</xsl:text>
    </xsl:message>
  </xsl:template>

  <xsl:template match="function[@name]|predicate[@name]">
    <xsl:if test="parent::quantifier">
      <xsl:text>(</xsl:text>
    </xsl:if>
    <xsl:value-of select="@name"/>
    <xsl:if test="count(*) &gt; 0">
      <xsl:text> </xsl:text>
      <xsl:call-template name="ilist">
        <xsl:with-param name="separ">
          <xsl:text>,</xsl:text>
        </xsl:with-param>
        <xsl:with-param name="elems" select="*"/>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="parent::quantifier">
      <xsl:text>)</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="binary-connective">
    <xsl:param name="connective"/>
    <xsl:text>(</xsl:text>
    <xsl:apply-templates select="*[1]"/>
    <xsl:text> </xsl:text>
    <xsl:value-of select="$connective"/>
    <xsl:text> </xsl:text>
    <xsl:apply-templates select="*[2]"/>
    <xsl:text>)</xsl:text>
  </xsl:template>

  <xsl:template match="*" mode="multiple-arity-connective">
    <xsl:param name="connective"/>
    <xsl:if test="count(*) &gt; 1">
      <xsl:text>(</xsl:text>
    </xsl:if>
    <xsl:call-template name="ilist">
      <xsl:with-param name="separ" select="concat (&quot; &quot;, $connective, &quot; &quot;)"/>
      <xsl:with-param name="elems" select="*"/>
    </xsl:call-template>
    <xsl:if test="count(*) &gt; 1">
      <xsl:text>)</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="conjunction">
    <xsl:apply-templates select="." mode="multiple-arity-connective">
      <xsl:with-param name="connective">
        <xsl:text>&amp;</xsl:text>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>

  <!-- smart conjunction -->
  <xsl:template match="conjunction[predicate and conjunction]">
    <xsl:apply-templates select="predicate"/>
    <xsl:text> &amp; </xsl:text>
    <xsl:apply-templates select="conjunction"/>
  </xsl:template>

  <xsl:template match="disjunction">
    <xsl:apply-templates select="." mode="multiple-arity-connective">
      <xsl:with-param name="connective">
        <xsl:text>or</xsl:text>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>

  <!-- smart disjunction -->
  <xsl:template match="disjunction[predicate and disjunction]">
    <xsl:apply-templates select="predicate"/>
    <xsl:text> &amp; </xsl:text>
    <xsl:apply-templates select="disjunction"/>
  </xsl:template>

  <xsl:template match="implication">
    <xsl:apply-templates select="." mode="binary-connective">
      <xsl:with-param name="connective">
        <xsl:text>implies</xsl:text>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="equivalence">
    <xsl:apply-templates select="." mode="binary-connective">
      <xsl:with-param name="connective">
        <xsl:text>iff</xsl:text>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>

  <!-- the name 'equal' as a defined-predicate: from an older version of tptp? -->
  <xsl:template match="defined-predicate[@name=&apos;equal&apos;]">
    <xsl:if test="parent::quantifier">
      <xsl:text>(</xsl:text>
    </xsl:if>
    <xsl:text> </xsl:text>
    <xsl:apply-templates select="*[1]"/>
    <xsl:text> = </xsl:text>
    <xsl:apply-templates select="*[2]"/>
    <xsl:text> </xsl:text>
    <xsl:if test="parent::quantifier">
      <xsl:text>)</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="predicate[@name = &quot;=&quot;]">
    <xsl:if test="parent::quantifier">
      <xsl:text>(</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="*[1]"/>
    <xsl:text> = </xsl:text>
    <xsl:apply-templates select="*[2]"/>
    <xsl:if test="parent::quantifier">
      <xsl:text>)</xsl:text>
    </xsl:if>
  </xsl:template>

  <!-- //////////////////////////////////////////////////////////////////// -->
  <!-- Defined predicates -->
  <!-- //////////////////////////////////////////////////////////////////// -->
  <xsl:template match="defined-predicate[not(@name)]">
    <xsl:message terminate="yes">
      <xsl:text>Error: unable to render a defined-predicate element that lacks a name attribute.</xsl:text>
    </xsl:message>
  </xsl:template>

  <xsl:template match="defined-predicate[@name and not(@name = &quot;true&quot; or @name = &quot;false&quot;)]">
    <xsl:variable name="n" select="@name"/>
    <xsl:variable name="message" select="concat (&quot;Error: we are unable to handle a defined-predicate element whose name is &apos;&quot;, $n, &quot;&apos;; we are able to handle only defined-predicates whose name is either &apos;true&apos; or &apos;false&apos;.&quot;)"/>
    <xsl:message terminate="yes">
      <xsl:value-of select="$message"/>
    </xsl:message>
  </xsl:template>

  <xsl:template match="defined-predicate[@name = &quot;false&quot;]">
    <xsl:text>contradiction</xsl:text>
  </xsl:template>

  <xsl:template match="defined-predicate[@name = &quot;true&quot;]">
    <xsl:text>not contradiction</xsl:text>
  </xsl:template>

  <xsl:template match="non-logical-data"/>

  <xsl:template name="ilist">
    <xsl:param name="separ"/>
    <xsl:param name="elems"/>
    <xsl:for-each select="$elems">
      <xsl:apply-templates select="."/>
      <xsl:if test="not(position()=last())">
        <xsl:value-of select="$separ"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
