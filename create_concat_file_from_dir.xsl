<?xml version="1.0" encoding="UTF-8"?>
<!--
MIT License

Copyright 2019 Institut für Rundfunktechnik GmbH, Munich, Germany

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
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:sch="http://purl.oclc.org/dsdl/schematron"
    xmlns:vib="http://www.irt.de/irt_restxq/video_image_burner"
    exclude-result-prefixes="xs sch vib"
    version="2.0">
    
    <xsl:output encoding="UTF-8" method="text"/>
    
    <xsl:param name="img_file_extension" select="'png'"/>
    <xsl:param name="files" as="xs:string" required="yes"/>
    
    <!-- extracts the timecode from a filename -->
    <xsl:function name="vib:get_tc" as="xs:decimal">
        <xsl:param name="file" as="xs:string"/>
        <xsl:sequence select="xs:decimal(replace($file, '\.[^.]+$', ''))"/>
    </xsl:function>
    
    <!-- returns a sorted list of files -->
    <xsl:function name="vib:sort_files" as="xs:string*">
        <xsl:param name="unsorted_files" as="xs:string*"/>
        <xsl:perform-sort select="$unsorted_files">
            <xsl:sort select="vib:get_tc(.)"/>
        </xsl:perform-sort>
    </xsl:function>
    
    <!-- returns an output entry corresponding to a single image -->
    <xsl:function name="vib:output_entry" as="xs:string">
        <xsl:param name="tc_begin" as="xs:decimal"/>
        <xsl:param name="tc_end" as="xs:decimal"/>
        <xsl:param name="output_duration" as="xs:boolean"/>
        
        <xsl:variable name="filename" select="concat('file ', $tc_begin, '.', $img_file_extension)"/>
        <xsl:variable name="duration" select="concat('duration ', $tc_end - $tc_begin)"/>
        
        <xsl:value-of select="$filename, if ($output_duration) then $duration else ()" separator="&#xa;"/>
    </xsl:function>
    
   
    <!-- output concat file, omitting duration for last image -->
    <xsl:template match="/">
        <xsl:variable name="files_ordered" select="vib:sort_files(tokenize($files, ';'))"/>
        <xsl:value-of select="
            'ffconcat version 1.0',
            for $x in 1 to (count($files_ordered) - 1) return vib:output_entry(vib:get_tc($files_ordered[$x]), vib:get_tc($files_ordered[$x + 1]), true()),
            vib:output_entry(vib:get_tc($files_ordered[position() eq last()]), vib:get_tc($files_ordered[position() eq last()]), false())
            " separator="&#xa;&#xa;"/>
    </xsl:template>
</xsl:stylesheet>