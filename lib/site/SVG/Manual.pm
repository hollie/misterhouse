package SVG::Manual;

=pod 

=head1 NAME

SVG - Perl extension for generating Scalable Vector Graphics (SVG) documents

=head2 VERSION

Version 2.24 (29.01.03)
Covers SVG-2.27 distribution

=head1 SYNOPSIS

    #!/usr/bin/perl -w
    use strict;
    use SVG;

    # create an SVG object
    my $svg= SVG->new(width=>200,height=>200);

    # use explicit element constructor to generate a group element
    my $y=$svg->group(
        id    => 'group_y',
        style => { stroke=>'red', fill=>'green' }
    );

    # add a circle to the group
    $y->circle(cx=>100, cy=>100, r=>50, id=>'circle_in_group_y');

    # or, use the generic 'tag' method to generate a group element by name
    my $z=$svg->tag('g',
                    id    => 'group_z',
                    style => {
                        stroke => 'rgb(100,200,50)',
                        fill   => 'rgb(10,100,150)'
                    }
                );

    # create and add a circle using the generic 'tag' method
    $z->tag('circle', cx=>50, cy=>50, r=>100, id=>'circle_in_group_z');

    # create an anchor on a rectangle within a group within the group z
    my $k = $z->anchor(
        id      => 'anchor_k',
        -href   => 'http://test.hackmare.com/',
        -target => 'new_window_0'
    )->rectangle(
        x     => 20, y      => 50,
        width => 20, height => 30,
        rx    => 10, ry     => 5,
        id    => 'rect_k_in_anchor_k_in_group_z'
    );

    # now render the SVG object, implicitly use svg namespace
    print $svg->xmlify;

    # or render a child node of the SVG object without rendering the entire object
    print $k->xmlify; #renders the anchor $k above containing a rectangle, but does not
                      #render any of the ancestor nodes of $k


    # or, explicitly use svg namespace and generate a document with its own DTD
    print $svg->xmlify(-namespace=>'svg');

    # or, explicitly use svg namespace and generate an in-line docunent
    print $svg->xmlify(
        -namespace => "svg",
        -pubid => "-//W3C//DTD SVG 1.0//EN",
        -inline   => 1
    );

=head1 DESCRIPTION

SVG is a 100% Perl module which generates a nested data structure containing the
DOM representation of an SVG (Scalable Vector Graphics) image. Using SVG, you
can generate SVG objects, embed other SVG instances into it, access the DOM
object, create and access javascript, and generate SMIL animation content.

=head2 General Steps to generating an SVG document

Generating SVG is a simple three step process:

=over 4

=item 1 The first step is to construct a new SVG object with L<"new">.

=item 2 The second step is to call element constructors to create SVG elements.
Examples of element constructors are L<"circle"> and L<"path">.

=item 3 The third and last step is to render the SVG object into XML using the
L<"xmlify"> method.

=back

The L<"xmlify"> method takes a number of optional arguments that control how SVG
renders the object into XML, and in particular determine whether a stand-alone
SVG document or an inline SVG document fragment is generated:

=over (

=item -stand-alone

A complete SVG document with its own associated DTD. A namespace for the SVG
elements may be optionally specified.

=item -in-line

An in-line SVG document fragment with no DTD that be embedded within other XML
content. As with stand-alone documents, an alternate namespace may be specified.

=back

No XML content is generated until the third step is reached. Up until this
point, all constructed element definitions reside in a DOM-like data structure
from which they can be accessed and modified.

=head2 EXPORTS

None. However, SVG permits both options and additional element methods to be
specified in the import list. These options and elements are then available
for all SVG instances that are created with the L<"new"> constructor. For example,
to change the indent string to two spaces per level:

    use SVG qw(-indent => "  ");

With the exception of -auto, all options may also be specified to the L<"new">
constructor. The currently supported options are:

    -auto        enable autoloading of all unrecognised method calls (0)
    -indent      the indent to use when rendering the SVG into XML ("\t")
    -inline      whether the SVG is to be standalone or inlined (0)
    -printerror  print SVG generation errors to standard error (1)
    -raiseerror  die if a generation error is encountered (1)
    -nostub      only return the handle to a blank SVG document without any elements

SVG also allows additional element generation methods to be specified in the
import list. For example to generate 'star' and 'planet' element methods:

    use SVG qw(star planet);

or:

    use SVG ("star","planet");

This will add 'star' to the list of elements supported by SVG.pm (but not of
course other SVG parsers...). Alternatively the '-auto' option will allow
any unknown method call to generate an element of the same name:

    use SVG (-auto => 1, "star", "planet");

Any elements specified explicitly (as 'star' and 'planet' are here) are
predeclared; other elements are defined as and when they are seen by Perl. Note
that enabling '-auto' effectively disables compile-time syntax checking for
valid method names.

B<Example:>

    use SVG (
        -auto       => 0,
        -indent     => "  ",
        -raiserror  => 0,
        -printerror => 1,
        "star", "planet", "moon"
    );

=head1 SEE ALSO

    perl(1), L<SVG::XML>, L<SVG::Element>, L<SVG::DOM>, L<SVG::Parser>
    http://roasp.com/
    http://www.w3c.org/Graphics/SVG/

=head1 AUTHOR

Ronan Oger, RO IT Systemms GmbH, ronan@roasp.com

=head1 CREDITS

Peter Wainwright, peter@roasp.com Excellent ideas, beta-testing, SVG::Parser
Fredo, http://www.penguin.at0.net/~fredo/ - provided initial feedback
for early SVG.pm versions
Adam Schneider, improvements to xmlescp providing improved character support
Brial Pilpré, I do not remember.

=head1 EXAMPLES

http://roasp.com/

See also the examples directory in this distribution which contain several fully documented examples.

=pod

=head1 WINDOWS DISTRIBUTION

http://roasp.com/ppm/

=pod

=head1 METHODS

SVG provides both explicit and generic element constructor methods. Explicit
generators are generally (with a few exceptions) named for the element they
generate. If a tag method is required for a tag containing hyphens, the method 
name replaces the hyphen with an underscore. ie: to generate tag <column-heading id="new">
you would use method $svg->column_heading(id=>'new').


All element constructors take a hash of element attributes and options;
element attributes such as 'id' or 'border' are passed by name, while options for the
method (such as the type of an element that supports multiple alternate forms)
are passed preceded by a hyphen, e.g '-type'. Both types may be freely
intermixed; see the L<"fe"> method and code examples througout the documentation
for more examples.

=head2 new (constructor)

$svg = SVG->new(%attributes)

Creates a new SVG object. Attributes of the document SVG element be passed as
an optional list of key value pairs. Additionally, SVG options (prefixed with
a hyphen) may be set on a per object basis:

B<Example:>

    my $svg1=new SVG;

    my $svg2=new SVG(id => 'document_element');

    my $svg3=new SVG(s
        -printerror => 1,
        -raiseerror => 0,
        -indent     => '  ',
        -docroot => 'svg', #default document root element (SVG specification assumes svg). Defaults to 'svg' if undefined
        -sysid      => 'abc', #optional system identifyer 
        -pubid      => "-//W3C//DTD SVG 1.0//EN", #public identifyer default value is "-//W3C//DTD SVG 1.0//EN" if undefined
        -namespace => 'mysvg',
        -inline   => 1
        id          => 'document_element',
        width       => 300,
        height      => 200,
    );

Default SVG options may also be set in the import list. See L<"EXPORTS"> above
for more on the available options. 

Furthermore, the following options:

  
    -version
    -encoding
    -standalone
    -namespace Defines the document or element level namespace. The order of assignment priority is element,document .
    -inline
    -identifier
    -nostub
    -dtd (standalone)

may also be set in xmlify, overriding any corresponding values set in the SVG->new declaration


=head2 xmlify (alias: to_xml render)

$string = $svg->xmlify(%attributes);

Returns xml representation of svg document.

B<XML Declaration>

    Name               Default Value
    -version           '1.0'               
    -encoding          'UTF-8'
    -standalone        'yes'
    -namespace         'svg'                - namespace for elements
    -inline            '0' - If '1', then this is an inline document.
    -pubid             '-//W3C//DTD SVG 1.0//EN';
    -dtd (standalone)  'http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd'


=head2 tag (alias: element)
 
$tag = $svg->tag($name, %attributes)

Generic element generator. Creates the element named $name with the attributes
specified in %attributes. This method is the basis of most of the explicit
element generators.

B<Example:>

    my $tag = $svg->tag('g', transform=>'rotate(-45)');


=head2 anchor

$tag = $svg->anchor(%attributes)

Generate an anchor element. Anchors are put around objects to make them
'live' (i.e. clickable). It therefore requires a drawn object or group element
as a child.

B<Example:>

    # generate an anchor	
    $tag = $svg->anchor(
        -href=>'http://here.com/some/simpler/svg.svg'
    );
    # add a circle to the anchor. The circle can be clicked on.
    $tag->circle(cx=>10,cy=>10,r=>1);

    # more complex anchor with both URL and target
    $tag = $svg->anchor(
	      -href   => 'http://somewhere.org/some/other/page.html',
	      -target => 'new_window'
    );



=head2 circle

$tag = $svg->circle(%attributes)

Draw a circle at (cx,cy) with radius r.

B<Example:>

    my $tag = $svg->circle(cx=>4, cy=>2, r=>1);

=head2 ellipse

$tag = $svg->ellipse(%attributes)

Draw an ellipse at (cx,cy) with radii rx,ry.

B<Example:>

    my $tag = $svg->ellipse(
        cx=>10, cy=>10,
        rx=>5, ry=>7,
        id=>'ellipse',
        style=>{
            'stroke'=>'red',
            'fill'=>'green',
            'stroke-width'=>'4',
            'stroke-opacity'=>'0.5',
            'fill-opacity'=>'0.2'
        }
    );


=head2 rectangle (alias: rect)

$tag = $svg->rectangle(%attributes)

Draw a rectangle at (x,y) with width 'width' and height 'height' and side radii
'rx' and 'ry'.

B<Example:>

    $tag = $svg->rectangle(
        x=>10, y=>20,
        width=>4, height=>5,
        rx=>5.2, ry=>2.4,
        id=>'rect_1'
    );

=head2 image

 $tag = $svg->image(%attributes)

Draw an image at (x,y) with width 'width' and height 'height' linked to image
resource '-href'. See also L<"use">.

B<Example:>

    $tag = $svg->image(
        x=>100, y=>100,
        width=>300, height=>200,
        '-href'=>"image.png", #may also embed SVG, e.g. "image.svg"
        id=>'image_1'
    );

B<Output:>

    <image xlink:href="image.png" x="100" y="100" width="300" height="200"/>

=head2 use

$tag = $svg->use(%attributes)

Retrieve the content from an entity within an SVG document and apply it at
(x,y) with width 'width' and height 'height' linked to image resource '-href'.

B<Example:>

    $tag = $svg->use(
        x=>100, y=>100,
        width=>300, height=>200,
        '-href'=>"pic.svg#image_1",
        id=>'image_1'
    );

B<Output:>

    <use xlink:href="pic.svg#image_1" x="100" y="100" width="300" height="200"/>

According to the SVG specification, the 'use' element in SVG can point to a
single element within an external SVG file.

=head2 polygon

$tag = $svg->polygon(%attributes)

Draw an n-sided polygon with vertices at points defined by a string of the form
'x1,y1,x2,y2,x3,y3,... xy,yn'. The L<"get_path"> method is provided as a
convenience to generate a suitable string from coordinate data.

B<Example:>

    # a five-sided polygon
    my $xv = [0,2,4,5,1];
    my $yv = [0,0,2,7,5];

    $points = $a->get_path(
        x=>$xv, y=>$yv,
        -type=>'polygon'
    );

    $c = $a->polygon(
        %$points,
        id=>'pgon1',
        style=>\%polygon_style
    );

SEE ALSO:

L<"polyline">, L<"path">, L<"get_path">.


=head2 polyline

$tag = $svg->polyline(%attributes)

Draw an n-point polyline with points defined by a string of the form
'x1,y1,x2,y2,x3,y3,... xy,yn'. The L<"get_path"> method is provided as a
convenience to generate a suitable string from coordinate data.

B<Example:>

    # a 10-pointsaw-tooth pattern
    my $xv = [0,1,2,3,4,5,6,7,8,9];
    my $yv = [0,1,0,1,0,1,0,1,0,1];

    $points = $a->get_path(
        x=>$xv, y=>$yv,
        -type=>'polyline',
        -closed=>'true' #specify that the polyline is closed.
    );

    my $tag = $a->polyline (
        %$points,
        id=>'pline_1',
        style=>{
            'fill-opacity'=>0,
            'stroke-color'=>'rgb(250,123,23)'
        }
    );

=head2 line

$tag = $svg->line(%attributes)

Draw a straight line between two points (x1,y1) and (x2,y2).

B<Example:>

    my $tag = $svg->line(
        id=>'l1',
        x1=>0, y1=>10,
        x2=>10, y2=>0
    );

To draw multiple connected lines, use L<"polyline">.

=head2 text

$text = $svg->text(%attributes)->cdata();

$text_path = $svg->text(-type=>'path');
$text_span = $text_path->text(-type=>'span')->cdata('A');
$text_span = $text_path->text(-type=>'span')->cdata('B');
$text_span = $text_path->text(-type=>'span')->cdata('C');


define the container for a text string to be drawn in the image.

B<Input:> 
    -type     = path type (path | polyline | polygon)
    -type     = text element type  (path | span | normal [default])

B<Example:>

    my $text1 = $svg->text(
        id=>'l1', x=>10, y=>10
    )->cdata('hello, world');

    my $text2 = $svg->text(
        id=>'l1', x=>10, y=>10, -cdata=>'hello, world');

    my $text = $svg->text(
        id=>'tp', x=>10, y=>10 -type=>path)
        ->text(id=>'ts' -type=>'span')
        ->cdata('hello, world');

SEE ALSO:

    L<"desc">, L<"cdata">.

=head2 title

$tag = $svg->title(%attributes)

Generate the title of the image.

B<Example:>

    my $tag = $svg->title(id=>'document-title')->cdata('This is the title');

=head2 desc

$tag = $svg->desc(%attributes)

Generate the description of the image.

B<Example:>

    my $tag = $svg->desc(id=>'document-desc')->cdata('This is a description');

=head2 comment

$tag = $svg->comment(@comments)

Generate the description of the image.

B<Example:>

    my $tag = $svg->comment('comment 1','comment 2','comment 3');

=head2 pi (Processing Instruction)

$tag = $svg->pi(@pi)

Generate a set of processing instructions

B<Example:>

    my $tag = $svg->pi('instruction one','instruction two','instruction three');

    returns: 
      <lt>?instruction one?<gt>
      <lt>?instruction two?<gt>
      <lt>?instruction three?<gt>

=head2 script

$tag = $svg->script(%attributes)

Generate a script container for dynamic (client-side) scripting using
ECMAscript, Javascript or other compatible scripting language.

B<Example:>

    my $tag = $svg->script(-type=>"text/ecmascript");

    # populate the script tag with cdata
    # be careful to manage the javascript line ends.
    # qq|text| or qq§text§ where text is the script 
    # works well for this.

    $tag->cdata(qq|function d(){
        //simple display function
        for(cnt = 0; cnt < d.length; cnt++)
            document.write(d[cnt]);//end for loop
        document.write("<BR>");//write a line break
      }|
    );

=head2 path

$tag = $svg->path(%attributes)

Draw a path element. The path vertices may be imputed as a parameter or
calculated usingthe L<"get_path"> method.

B<Example:>

    # a 10-pointsaw-tooth pattern drawn with a path definition
    my $xv = [0,1,2,3,4,5,6,7,8,9];
    my $yv = [0,1,0,1,0,1,0,1,0,1];

    $points = $a->get_path(
        x => $xv,
        y => $yv,
        -type   => 'path',
        -closed => 'true'  #specify that the polyline is closed
    );

    $tag = $svg->path(
        %$points,
        id    => 'pline_1',
        style => {
            'fill-opacity' => 0,
            'fill-color'   => 'green',
            'stroke-color' => 'rgb(250,123,23)'
        }
    );


SEE ALSO:

L<"get_path">.

=head2 get_path

$path = $svg->get_path(%attributes)

Returns the text string of points correctly formatted to be incorporated into
the multi-point SVG drawing object definitions (path, polyline, polygon)

B<Input:> attributes including:

    -type     = path type (path | polyline | polygon)
    x         = reference to array of x coordinates
    y         = reference to array of y coordinates

B<Output:> a hash reference consisting of the following key-value pair:

    points    = the appropriate points-definition string
    -type     = path|polygon|polyline
    -relative = 1 (define relative position rather than absolute position)
    -closed   = 1 (close the curve - path and polygon only)

B<Example:>

    #generate an open path definition for a path.
    my ($points,$p);
    $points = $svg->get_path(x=&gt\@x,y=&gt\@y,-relative=&gt1,-type=&gt'path');
 
    #add the path to the SVG document
    my $p = $svg->path(%$path, style=>\%style_definition);

    #generate an closed path definition for a a polyline.
    $points = $svg->get_path(
        x=>\@x,
        y=>\@y,
        -relative=>1,
        -type=>'polyline',
        -closed=>1
    ); # generate a closed path definition for a polyline

    # add the polyline to the SVG document
    $p = $svg->polyline(%$points, id=>'pline1');

B<Aliases:> get_path set_path


=head2 animate

$tag = $svg->animate(%attributes)

Generate an SMIL animation tag. This is allowed within any nonempty tag. Refer\
to the W3C for detailed information on the subtleties of the animate SMIL
commands.

B<Inputs:> -method = Transform | Motion | Color

  my $an_ellipse = $svg->ellipse(
      cx=>30,cy=>150,rx=>10,ry=>10,id=>'an_ellipse',
      stroke=>'rgb(130,220,70)',fill=>'rgb(30,20,50)'); 

  $an_ellipse-> animate(
      attributeName=>"cx",values=>"20; 200; 20",dur=>"10s", repeatDur=>'indefinite');

  $an_ellipse-> animate(
      attributeName=>"rx",values=>"10;30;20;100;50",
      dur=>"10s", repeatDur=>'indefinite');

  $an_ellipse-> animate(
      attributeName=>"ry",values=>"30;50;10;20;70;150",
      dur=>"15s", repeatDur=>'indefinite');

  $an_ellipse-> animate(
      attributeName=>"rx",values=>"30;75;10;100;20;20;150",
      dur=>"20s", repeatDur=>'indefinite');

  $an_ellipse-> animate(
      attributeName=>"fill",values=>"red;green;blue;cyan;yellow",
      dur=>"5s", repeatDur=>'indefinite');

  $an_ellipse-> animate(
      attributeName=>"fill-opacity",values=>"0;1;0.5;0.75;1",
      dur=>"20s",repeatDur=>'indefinite');

  $an_ellipse-> animate(
      attributeName=>"stroke-width",values=>"1;3;2;10;5",
      dur=>"20s",repeatDur=>'indefinite');

=head2 group

$tag = $svg->group(%attributes)

Define a group of objects with common properties. groups can have style,
animation, filters, transformations, and mouse actions assigned to them.

B<Example:>

    $tag = $svg->group(
        id        => 'xvs000248',
        style     => {
            'font'      => [ qw( Arial Helvetica sans ) ],
            'font-size' => 10,
            'fill'      => 'red',
        },
        transform => 'rotate(-45)'
    );

=head2 defs

$tag = $svg->defs(%attributes)

define a definition segment. A Defs requires children when defined using SVG.pm
B<Example:>

    $tag = $svg->defs(id  =>  'def_con_one',);

=head2 style

$svg->tag('style', %styledef);

Sets/Adds style-definition for the following objects being created.

Style definitions apply to an object and all its children for all properties for
which the value of the property is not redefined by the child.

=head2 mouseaction

$svg->mouseaction(%attributes)

Sets/Adds mouse action definitions for tag


$svg->attrib($name, $value)

Sets/Adds mouse action definitions.

$svg->attrib $name, $value

$svg->attrib $name, \@value

$svg->attrib $name, \%value

Sets/Replaces attributes for a tag.

=head2 cdata

$svg->cdata($text)

Sets cdata to $text. SVG.pm allows you to set cdata for any tag. If the tag is
meant to be an empty tag, SVG.pm will not complain, but the rendering agent will
fail. In the SVG DTD, cdata is generally only meant for adding text or script
content.

B<Example:>

    $svg->text(
        style => {
            'font'      => 'Arial',
            'font-size' => 20
        })->cdata('SVG.pm is a perl module on CPAN!');

    my $text = $svg->text(style=>{'font'=>'Arial','font-size'=>20});
    $text->cdata('SVG.pm is a perl module on CPAN!');


B<Result:>

    E<lt>text style="font: Arial; font-size: 20" E<gt>SVG.pm is a perl module on CPAN!E<lt>/text E<gt>

SEE ALSO:

  L<"CDATA"> L<"desc">, L<"title">, L<"text">, L<"script">.

=head2 cdata_noxmlesc

 $script = $svg->script();
 $script->cdata_noxmlesc($text);

Generates cdata content for text and similar tags which do not get xml-escaped.
In othe words, does not parse the content and inserts the exact string into the cdata location.

=head2 CDATA

 $script = $svg->script();
 $script->CDATA($text);

Generates a <![CDATA[ ... ]]> tag with the contents of $text rendered exactly as supplied. SVG.pm allows you to set cdata for any tag. If the tag is
meant to be an empty tag, SVG.pm will not complain, but the rendering agent will
fail. In the SVG DTD, cdata is generally only meant for adding text or script
content.

B<Example:>

      my $text = qq§
        var SVGDoc;
        var groups = new Array();
        var last_group;
        
        /*****
        *
        *   init
        *
        *   Find this SVG's document element
        *   Define members of each group by id
        *
        *****/
        function init(e) {
            SVGDoc = e.getTarget().getOwnerDocument();
            append_group(1, 4, 6); // group 0
            append_group(5, 4, 3); // group 1
            append_group(2, 3);    // group 2
        }§;
        $svg->script()->CDATA($text);


B<Result:>

    E<lt>script E<gt>
      <gt>![CDATA[
        var SVGDoc;
        var groups = new Array();
        var last_group;
        
        /*****
        *
        *   init
        *
        *   Find this SVG's document element
        *   Define members of each group by id
        *
        *****/
        function init(e) {
            SVGDoc = e.getTarget().getOwnerDocument();
            append_group(1, 4, 6); // group 0
            append_group(5, 4, 3); // group 1
            append_group(2, 3);    // group 2
        }
        ]]E<gt>

SEE ALSO:

  L<"cdata">, L<"script">.

=head2 filter

$tag = $svg->filter(%attributes)

Generate a filter. Filter elements contain L<"fe"> filter sub-elements.

B<Example:>

    my $filter = $svg->filter(
        filterUnits=>"objectBoundingBox",
        x=>"-10%",
        y=>"-10%",
        width=>"150%",
        height=>"150%",
        filterUnits=>'objectBoundingBox'
    );

    $filter->fe();

SEE ALSO:

L<"fe">.

=head2 fe

$tag = $svg->fe(-type=>'type', %attributes)

Generate a filter sub-element. Must be a child of a L<"filter"> element.

B<Example:>

    my $fe = $svg->fe(
        -type     => 'DiffuseLighting'  # required - element name omiting 'fe'
        id        => 'filter_1',
        style     => {
            'font'      => [ qw(Arial Helvetica sans) ],
            'font-size' => 10,
            'fill'      => 'red',
        },
        transform => 'rotate(-45)'
    );

Note that the following filter elements are currently supported:

=over 4

=item * feBlend 

=item * feColorMatrix 

=item * feComponentTransfer 

=item * feComposite

=item * feConvolveMatrix 

=item * feDiffuseLighting 

=item * feDisplacementMap 

=item * feDistantLight 

=item * feFlood 

=item * feFuncA 

=item * feFuncB 

=item * feFuncG 

=item * feFuncR 

=item * feGaussianBlur 

=item * feImage 

=item * feMerge 

=item * feMergeNode 

=item * feMorphology 

=item * feOffset 

=item * fePointLight

=item * feSpecularLighting 

=item * feSpotLight 

=item * feTile 

=item * feTurbulence 

=back

SEE ALSO:

L<"filter">.

=head2 pattern

$tag = $svg->pattern(%attributes)

Define a pattern for later reference by url.

B<Example:>

    my $pattern = $svg->pattern(
        id     => "Argyle_1",
        width  => "50",
        height => "50",
        patternUnits        => "userSpaceOnUse",
        patternContentUnits => "userSpaceOnUse"
    );

=head2 set

$tag = $svg->set(%attributes)

Set a definition for an SVG object in one section, to be referenced in other
sections as needed.

B<Example:>

    my $set = $svg->set(
        id     => "Argyle_1",
        width  => "50",
        height => "50",
        patternUnits        => "userSpaceOnUse",
        patternContentUnits => "userSpaceOnUse"
    );

=head2 stop

$tag = $svg->stop(%attributes)

Define a stop boundary for L<"gradient">

B<Example:>

   my $pattern = $svg->stop(
       id     => "Argyle_1",
       width  => "50",
       height => "50",
       patternUnits        => "userSpaceOnUse",
       patternContentUnits => "userSpaceOnUse"
   );

$tag = $svg->gradient(%attributes)

Define a color gradient. Can be of type B<linear> or B<radial>

B<Example:>

    my $gradient = $svg->gradient(
        -type => "linear",
        id    => "gradient_1"
    );

=head1 GENERIC ELEMENT METHODS

The following elements are generically supported by SVG:

=over 4

=item * altGlyph

=item * altGlyphDef

=item * altGlyphItem

=item * clipPath

=item * color-profile

=item * cursor

=item * definition-src

=item * font-face-format

=item * font-face-name

=item * font-face-src

=item * font-face-url

=item * foreignObject

=item * glyph

=item * glyphRef

=item * hkern

=item * marker

=item * mask

=item * metadata

=item * missing-glyph

=item * mpath

=item * switch

=item * symbol

=item * tref

=item * view

=item * vkern

=back

See e.g. L<"pattern"> for an example of the use of these methods.

=head1 METHODS IMPORTED BY SVG::DOM

The following L<SVG::DOM> elements are accessible through SVG:

=over 4

=item * getChildren

=item * getFirstChild

=item * getLastChild

=item * getParent

=item * getSiblings

=item * getElementByID

=item * getElementID

=item * getElements

=item * getElementName

=item * getParentElement

=item * getType

=item * getAttributes

=item * getAttribute

=item * setAttributes

=item * setAttribute

=back

=head1 SEE ALSO

perl(1),L<SVG>,L<SVG::DOM>,L<SVG::XML>,L<SVG::Element>,L<SVG::Parser>, L<SVG::Manual>
http://www.roasp.com/
http://www.perlsvg.com/
http://www.roitsystems.com/
http://www.w3c.org/Graphics/SVG/

=cut
