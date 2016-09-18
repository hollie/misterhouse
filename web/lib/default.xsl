<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="/misterhouse">
    <html>

      <head>
        <link rel="stylesheet" href="/lib/default.css" type="text/css" />
      </head>

      <body>
        <xsl:for-each select="objects">
          <xsl:call-template name="object"/>
        </xsl:for-each>
        <xsl:for-each select="print_log">
          <ul>
          <li>Print Log:</li>
          <ul>
          <xsl:for-each select="time">
            <li>Time=<xsl:value-of select="."/></li>
          </xsl:for-each>
          <xsl:for-each select="text">
            <li>Text:<ul>
              <xsl:for-each select="value">
                <li style="white-space:pre;">
                  <xsl:value-of select="."/>
                </li>
              </xsl:for-each>
              </ul>
            </li>
          </xsl:for-each>
          </ul>
          </ul>
        </xsl:for-each>
        <xsl:for-each select="print_speaklog">
          <ul>
          <li>Speak Log:</li>
          <ul>
          <xsl:for-each select="time">
            <li>Time=<xsl:value-of select="."/></li>
          </xsl:for-each>
          <xsl:for-each select="text">
            <li>Text:<ul>
              <xsl:for-each select="value">
                <li style="white-space:pre;">
                  <xsl:value-of select="."/>
                </li>
              </xsl:for-each>
              </ul>
            </li>
          </xsl:for-each>
          </ul>
          </ul>
        </xsl:for-each>
        <xsl:for-each select="//vars">
          <ul>
            <xsl:call-template name="var"/>
          </ul>
        </xsl:for-each>
        <ul>
          <xsl:for-each select="categories/category|groups/group|types/type">
            <li>
              <xsl:call-template name="link"/>
              <xsl:for-each select="objects">
                <xsl:call-template name="object"/>
              </xsl:for-each>
            </li>
          </xsl:for-each>
        </ul>
      </body>

    </html>
  </xsl:template>

  <xsl:template name="object">
    <ul>
      <xsl:for-each select="object">
        <li>
          <xsl:call-template name="link"/>
          <ul>
            <xsl:for-each select="./*[position() > 1]">
              <li>
                <xsl:value-of select="local-name()"/>
                <xsl:choose>
                  <xsl:when test="value">
                    <ul>
                      <xsl:for-each select="value">
                        <li>
                          <xsl:value-of select="."/>
                        </li>
                      </xsl:for-each>
                    </ul>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:text>=</xsl:text>
                    <xsl:value-of select="."/>
                  </xsl:otherwise>
                </xsl:choose>
              </li>
            </xsl:for-each>
          </ul>
        </li>
      </xsl:for-each>
    </ul>
  </xsl:template>

  <xsl:template name="var">
    <xsl:for-each select="var">
      <li>
        <xsl:call-template name="link"/>
        <xsl:if test="value">
          <xsl:text>=</xsl:text>
          <xsl:value-of select="value"/>
        </xsl:if>
      </li>
      <xsl:if test="var">
        <ul>
          <xsl:call-template name="var"/>
        </ul>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="link">
    <xsl:element name="a">
      <xsl:attribute name="href">
        <xsl:text>/sub?xml(</xsl:text>
        <xsl:value-of select="local-name(..)"/>
        <xsl:text>=</xsl:text>
        <xsl:variable name="apos">'</xsl:variable>
        <xsl:variable name="bsapos">\'</xsl:variable>
        <xsl:call-template name="replace-string">
          <xsl:with-param name="text">
            <xsl:call-template name="replace-string">
              <xsl:with-param name="text">
                <xsl:call-template name="replace-string">
                  <xsl:with-param name="text" select="name"/>
                  <xsl:with-param name="replace" select="$apos"/>
                  <xsl:with-param name="with" select="$bsapos"/>
                </xsl:call-template>
              </xsl:with-param>
              <xsl:with-param name="replace" select="'%'"/>
              <xsl:with-param name="with" select="'%25'"/>
            </xsl:call-template>
          </xsl:with-param>
          <xsl:with-param name="replace" select="'&amp;'"/>
          <xsl:with-param name="with" select="'%26'"/>
        </xsl:call-template>
        <xsl:text>)</xsl:text>
      </xsl:attribute>
      <xsl:value-of select="name"/>
    </xsl:element>
  </xsl:template>

  <xsl:template name="replace-string">
    <xsl:param name="text"/>
    <xsl:param name="replace"/>
    <xsl:param name="with"/>
    <xsl:choose>
      <xsl:when test="contains($text,$replace)">
        <xsl:value-of select="substring-before($text,$replace)"/>
        <xsl:value-of select="$with"/>
        <xsl:call-template name="replace-string">
          <xsl:with-param name="text" select="substring-after($text,$replace)"/>
          <xsl:with-param name="replace" select="$replace"/>
          <xsl:with-param name="with" select="$with"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
