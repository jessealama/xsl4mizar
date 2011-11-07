<?xml version='1.0' encoding='UTF-8'?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text"/>
  <xsl:strip-space elements="*"/>

  <!-- MML Query needs numbers for proper display of indeces, -->
  <!-- hence this poor-man's numberization of proof-levels -->
  <xsl:template name="usto0">
    <xsl:param name="s"/>
    <xsl:value-of select="translate($s, &quot;_&quot;, &quot;0&quot;)"/>
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
    <!-- give the type 'set' to all variables appearing in the problem -->
    <xsl:for-each select="descendant::variable[@name
                                 and not(@name = preceding::variable[@name]/@name)]">
      <xsl:apply-templates select="." mode="set"/>
    </xsl:for-each>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="comment"/>

  <xsl:template match="formula[not(@name)]">
    <xsl:message terminate="yes">
      <xsl:text>We encountered a formula element that lacks a name attribute.</xsl:text>
    </xsl:message>
  </xsl:template>

  <xsl:template match="formula[@name]">
    <xsl:value-of select="@name"/>
    <xsl:text>: </xsl:text>
    <xsl:apply-templates select="*[1]"/>
    <xsl:text>;
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
    <xsl:text/>
  </xsl:template>

  <xsl:template match="quantifier[@type = &quot;universal&quot;]">
    <xsl:text>for </xsl:text>
    <xsl:call-template name="ilist">
      <xsl:with-param name="separ">
        <xsl:text>,</xsl:text>
      </xsl:with-param>
      <xsl:with-param name="elems" select="variable"/>
    </xsl:call-template>
    <xsl:text> holds </xsl:text>
    <xsl:apply-templates select="*[position() = last()]"/>
    <xsl:text/>
  </xsl:template>

  <xsl:template match="negation|">
    <xsl:text> not </xsl:text>
    <xsl:apply-templates/>
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="function|predicate">
    <xsl:if test="name(..)=&quot;quantifier&quot;">
      <xsl:text>(</xsl:text>
    </xsl:if>
    <xsl:variable name="tc">
      <xsl:call-template name="transl_constr">
        <xsl:with-param name="nm" select="@name"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="contains($tc, &quot;:attr&quot;) or contains($tc, &quot;:mode&quot;)  or contains($tc, &quot;:struct&quot;)">
        <xsl:text> is </xsl:text>
        <xsl:apply-templates select="*[1]"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="$tc"/>
        <xsl:text>(</xsl:text>
        <xsl:call-template name="ilist">
          <xsl:with-param name="separ">
            <xsl:text>,</xsl:text>
          </xsl:with-param>
          <xsl:with-param name="elems" select="*[position()&gt;1]"/>
        </xsl:call-template>
        <xsl:text>)</xsl:text>
        <xsl:text>)</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$tc"/>
        <xsl:if test="count(*)&gt;0">
          <xsl:text>(</xsl:text>
          <xsl:call-template name="ilist">
            <xsl:with-param name="separ">
              <xsl:text>,</xsl:text>
            </xsl:with-param>
            <xsl:with-param name="elems" select="*"/>
          </xsl:call-template>
          <xsl:text>)</xsl:text>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:if test="name(..)=&quot;quantifier&quot;">
      <xsl:text>)</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="conjunction">
    <xsl:text> </xsl:text>
    <xsl:call-template name="ilist">
      <xsl:with-param name="separ">
        <xsl:text> &amp; </xsl:text>
      </xsl:with-param>
      <xsl:with-param name="elems" select="*"/>
    </xsl:call-template>
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="disjunction">
    <xsl:text> </xsl:text>
    <xsl:call-template name="ilist">
      <xsl:with-param name="separ">
        <xsl:text> or </xsl:text>
      </xsl:with-param>
      <xsl:with-param name="elems" select="*"/>
    </xsl:call-template>
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="implication">
    <xsl:text> </xsl:text>
    <xsl:apply-templates select="*[1]"/>
    <xsl:text> implies </xsl:text>
    <xsl:text/>
    <xsl:apply-templates select="*[2]"/>
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="equivalence">
    <xsl:text> </xsl:text>
    <xsl:apply-templates select="*[1]"/>
    <xsl:text> iff </xsl:text>
    <xsl:text/>
    <xsl:apply-templates select="*[2]"/>
    <xsl:text> </xsl:text>
  </xsl:template>

  <!-- the name 'equal' as a defined-predicate: from an older version of tptp? -->
  <xsl:template match="defined-predicate[@name=&apos;equal&apos;]">
    <xsl:if test="parent::quantifier">
      <xsl:text>(</xsl:text>
    </xsl:if>
    <xsl:text> </xsl:text>
    <xsl:apply-templates select="*[1]"/>
    <xsl:text> = </xsl:text>
    <xsl:text/>
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
    <xsl:text/>
    <xsl:apply-templates select="*[2]"/>
    <xsl:if test="parent::quantifier">
      <xsl:text>)</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="defined-predicate[@name=&apos;false&apos;]">
    <xsl:text> contradiction </xsl:text>
  </xsl:template>

  <xsl:template match="defined-predicate[@name=&apos;true&apos;]">
    <xsl:text> not contradiction </xsl:text>
  </xsl:template>

  <xsl:template match="non-logical-data">
    <!-- there can be embedded inferences -->
    <xsl:choose>
      <xsl:when test="@name=&apos;inference&apos;">
        <xsl:for-each select="*[1]">
          <xsl:value-of select="@name"/>
        </xsl:for-each>
        <xsl:text>(</xsl:text>
        <xsl:call-template name="ilist">
          <xsl:with-param name="separ">
            <xsl:text>,</xsl:text>
          </xsl:with-param>
          <xsl:with-param name="elems" select="*[3]/*[not(@name=&apos;theory&apos;)]"/>
        </xsl:call-template>
        <xsl:text>)</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>&lt;a href=&quot;#</xsl:text>
        <xsl:value-of select="@name"/>
        <xsl:text>&quot;&gt;</xsl:text>
        <xsl:value-of select="@name"/>
        <xsl:text>&lt;/a&gt;</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="transl_constr">
    <xsl:param name="nm"/>
    <xsl:value-of select="$nm"/>
  </xsl:template>

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

  <xsl:template name="notlist">
    <xsl:param name="separ"/>
    <xsl:param name="elems"/>
    <xsl:for-each select="$elems">
      <xsl:text>$not(</xsl:text>
      <xsl:apply-templates select="."/>
      <xsl:text>)</xsl:text>
      <xsl:if test="not(position()=last())">
        <xsl:value-of select="$separ"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="mkind">
    <xsl:param name="kind"/>
    <xsl:choose>
      <xsl:when test="$kind = &apos;m&apos;">
        <xsl:text>mode</xsl:text>
      </xsl:when>
      <xsl:when test="$kind = &apos;v&apos;">
        <xsl:text>attr</xsl:text>
      </xsl:when>
      <xsl:when test="$kind = &apos;r&apos;">
        <xsl:text>pred</xsl:text>
      </xsl:when>
      <xsl:when test="$kind = &apos;k&apos;">
        <xsl:text>func</xsl:text>
      </xsl:when>
      <xsl:when test="$kind = &apos;g&apos;">
        <xsl:text>aggr</xsl:text>
      </xsl:when>
      <xsl:when test="$kind = &apos;l&apos;">
        <xsl:text>struct</xsl:text>
      </xsl:when>
      <xsl:when test="$kind = &apos;u&apos;">
        <xsl:text>sel</xsl:text>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
