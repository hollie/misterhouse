=pod 

=head1 NAME

SVG::Element - Generate the element bits for SVG.pm

=head1 AUTHOR

Ronan Oger, ronan@roasp.com

=head1 SEE ALSO

perl(1),L<SVG>,L<SVG::XML>,L<SVG::Element>,L<SVG::Parser>, L<SVG::Manual>
http://www.roasp.com/
http://www.perlsvg.com/
http://www.roitsystems.com/
http://www.w3c.org/Graphics/SVG/

=cut

package SVG::Element;

$VERSION = "2.26";

use strict;
use SVG::XML;
use SVG::DOM;
use SVG::Extension;
use vars qw($AUTOLOAD %autosubs);

my @autosubs=qw(
    animateMotion animateColor animateTransform circle ellipse rect polyline 
    path polygon line title desc defs
    altGlyph altGlyphDef altGlyphItem clipPath color-profile
    cursor definition-src font-face-format font-face-name
    font-face-src font-face-url foreignObject glyph
    glyphRef hkern marker mask metadata missing-glyph
    mpath switch symbol textPath tref tspan view vkern marker textbox
    flowText style
);

%autosubs=map { $_ => 1 } @autosubs;

#-------------------------------------------------------------------------------

sub new ($$;@) {
    my ($proto,$name,%attrs)=@_;
    my $class=ref($proto) || $proto;
    my $self={-name => $name};
    foreach my $key (keys %attrs) {
        next if $key=~/^\-/;
        $self->{$key}=$attrs{$key};
    }

    return bless($self,$class);
}

#-------------------------------------------------------------------------------

sub release ($) {
    my $self=shift;

    foreach my $key (keys(%{$self})) {
        next if $key=~/^\-/;
        if (ref($self->{$key})=~/^SVG/) {
            eval { $self->{$key}->release; };
        }
        delete($self->{$key});
    }

    return $self;
}

sub xmlify ($) {
    my $self = shift;
    my $ns = $self->{-namespace} || $self->{-docref}->{-namespace} || undef;
    my $xml = '';
    #prep the attributes
    my %attrs;
    foreach my $k (keys(%{$self})) {
        if($k=~/^\-/) { next; }
        if(ref($self->{$k}) eq 'ARRAY') {
            $attrs{$k}=join(', ',@{$self->{$k}});
        } elsif(ref($self->{$k}) eq 'HASH') {
            $attrs{$k}=cssstyle(%{$self->{$k}});
        } elsif(ref($self->{$k}) eq '') {
            $attrs{$k}=$self->{$k};
        }
    }
    #prep the tag
    if($self->{-comment}) {
        $xml .= $self->xmlcomment($self->{-comment});
        return $xml;
    } elsif($self->{-pi}) {
        $xml .= $self->xmlpi($self->{-pi});
        return $xml;
    } elsif ($self->{-name} eq 'document') {
        #write the xml header
        $xml .= $self->xmldecl;
        #and write the dtd if this is inline
        $xml .= $self->dtddecl unless $self->{-inline};
        foreach my $k (@{$self->{-childs}}) {
            if(ref($k)=~/^SVG::Element/) {
                $xml .= $k->xmlify($ns);
            }
        }
        return $xml;
    } 
    if(defined $self->{-childs} ||
        defined $self->{-cdata} ||
        defined $self->{-CDATA} ||
        defined $self->{-cdata_noxmlesc}) {
        $xml .= $self->{-docref}->{-elsep};
        $xml .= $self->{-docref}->{-indent} x $self->{-docref}->{-level};
        $xml .= xmltagopen_ln($self->{-name},$ns,%attrs);
        $self->{-docref}->{-level}++;
        foreach my $k (@{$self->{-childs}}) {
            if(ref($k)=~/^SVG::Element/) {
                $xml .= $k->xmlify($ns);
            }
        }

        if(defined $self->{-cdata}) {
            $xml .= xmlescp($self->{-cdata});
        } 
        if(defined $self->{-CDATA}) {
            $xml .= '<![CDATA['.$self->{-CDATA}.']]>';
        }
        if(defined $self->{-cdata_noxmlesc}) {
            $xml .= $self->{-cdata_noxmlesc};
        }


        #return without writing the tag out if it the document tag
        $self->{-docref}->{-level}--;
        $xml .= $self->{-docref}->{-elsep};
        $xml .= $self->{-docref}->{-indent} x $self->{-docref}->{-level};
        $xml .= xmltagclose_ln($self->{-name},$ns);
    } else {
        $xml .= $self->{-docref}->{-elsep};
        $xml .= $self->{-docref}->{-indent} x $self->{-docref}->{-level};
        $xml .= xmltag_ln($self->{-name},$ns,%attrs);
    }
    #return the finished tag
    return $xml;
}

sub perlify {
    my $self=shift;
    my $code='';

    #prep the attributes
    my %attrs;
    foreach my $k (keys(%{$self})) {
        if($k=~/^\-/) { next; }
        if(ref($self->{$k}) eq 'ARRAY') {
            $attrs{$k}=join(', ',@{$self->{$k}});
        } elsif(ref($self->{$k}) eq 'HASH') {
            $attrs{$k}=cssstyle(%{$self->{$k}});
        } elsif(ref($self->{$k}) eq '') {
            $attrs{$k}=$self->{$k};
        }
    }

    if($self->{-comment}) {
        $code .= "->comment($self->{-comment})";
        return $code;
    } elsif($self->{-pi}) {
        $code .= "->pi($self->{-pi})";
        return $code;
    } elsif ($self->{-name} eq 'document') {
        #write the xml header
        #$xml .= $self->xmldecl;
        #and write the dtd if this is inline
        #$xml .= $self->dtddecl unless $self->{-inline};
        foreach my $k (@{$self->{-childs}}) {
            if(ref($k)=~/^SVG::Element/) {
                $code .= $k->perlify();
            }
        }
        return $code;
    }

    if (defined $self->{-childs}) {
        $code .= $self->{-docref}->{-elsep};
        $code .= $self->{-docref}->{-indent} x $self->{-docref}->{-level};
        $code .= $self->{-name}.'('.(join ', ',(map { "$_=>'$attrs{$_}'"} sort keys %attrs)).')';
        if ($self->{-cdata}) {
            $code.="->cdata($self->{-cdata})";
        } elsif ($self->{-CDATA}) {
            $code.="->CDATA($self->{-CDATA})";
        } elsif ($self->{-cdata_noxmlesc}) {
            $code.="->cdata_noxmlesc($self->{-cdata_noxmlesc})";
        }

        $self->{-docref}->{-level}++;
        foreach my $k (@{$self->{-childs}}) {
            if(ref($k)=~/^SVG::Element/) {
                $code .= $k->perlify();
            }
        }
        $self->{-docref}->{-level}--;
    } else {
        $code .= $self->{-docref}->{-elsep};
        $code .= $self->{-docref}->{-indent} x $self->{-docref}->{-level};
        $code .= $self->{-name}.'('.(join ', ',(map { "$_=>'$attrs{$_}'"} sort keys %attrs)).')';
    }

    return $code;
}
*toperl=\&perlify;


sub addchilds ($@) {
    my $self=shift;
    push @{$self->{-childs}},@_;
    return $self;
}

=pod

=head2 tag (alias: element)
 
$tag = $SVG->tag($name, %attributes)

Generic element generator. Creates the element named $name with the attributes
specified in %attributes. This method is the basis of most of the explicit
element generators.

B<Example:>

    my $tag = $SVG->tag('g', transform=>'rotate(-45)');

=cut

sub tag ($$;@) {
    my ($self,$name,%attrs)=@_;

    unless ($self->{-parent}) {
      #traverse down the tree until you find a non-document entry
      while ($self->{-document})  {$self = $self->{-document}}
    }
    my $tag=new SVG::Element($name,%attrs);

    #define the element namespace
    $tag->{-namespace}=$attrs{-namespace} if ($attrs{-namespace});

    #add the tag to the document element
    $tag->{-docref} = $self->{-docref};
    
    #create the empty idlist hash ref unless it already exists
    $tag->{-docref}->{-idlist} = {} 
        unless (defined $tag->{-docref}->{-idlist});
    
    #verify that the current id is unique. compain on exception
    #>>>TBD: add -strictids option to disable this check if desired
    if ($tag->{id}) {
        if ($self->getElementByID($tag->{id})) {
            $self->error($tag->{id} => "ID already exists in document");
            return undef;
        }
    }

    #add the current id reference to the document id hash
    $tag->{-docref}->{-idlist}->{$tag->{id}} = $tag if defined ($tag->{id});
    
    #create the empty idlist hash ref unless it already exists
    $tag->{-docref}->{-elist} = {} 
        unless (defined $tag->{-docref}->{-elist});
    
    #create the empty idlist hash ref unless it already exists
    $tag->{-docref}->{-elist}->{$tag->{-name}} = [] 
        unless (defined $tag->{-docref}->{-elist}->{$tag->{-name}});

    #add the current element ref to the corresponding element-hash array
    # -elist is a hash of element names. key name is element, content is object ref.

    # add the reference to $tag to the array of refs that belong to the
    # key $tag->{-name}.
    unshift    @{$tag->{-docref}->{-elist}->{$tag->{-name}}},$tag;

        # attach element to the DOM of the document
    $tag->{-parent}=$self;
    $tag->{-parentname}=$self->{-name};
    $self->addchilds($tag);

    return($tag);
}

*element=\&tag;

=pod

=head2 anchor

$tag = $SVG->anchor(%attributes)

Generate an anchor element. Anchors are put around objects to make them
'live' (i.e. clickable). It therefore requires a drawn object or group element
as a child.

B<Example:>

    # generate an anchor    
    $tag = $SVG->anchor(
        -href=>'http://here.com/some/simpler/SVG.SVG'
    );
    # add a circle to the anchor. The circle can be clicked on.
    $tag->circle(cx=>10,cy=>10,r=>1);

    # more complex anchor with both URL and target
    $tag = $SVG->anchor(
          -href   => 'http://somewhere.org/some/other/page.html',
          -target => 'new_window'
    );

=cut

sub anchor {
    my ($self,%attrs)=@_;
    my $an=$self->tag('a',%attrs);
    $an->{'xlink:href'}=$attrs{-href} if(defined $attrs{-href});
    $an->{'target'}=$attrs{-target} if(defined $attrs{-target});
    return($an);
}

sub svg {
    my ($self,%attrs)=@_;
    my $svg=$self->tag('svg',%attrs);
    $svg->{'height'} = '100%' unless ($svg->{'height'});
    $svg->{'width'}  = '100%' unless ($svg->{'width'});
    return($svg);
}

=pod

=head2 circle

$tag = $SVG->circle(%attributes)

Draw a circle at (cx,cy) with radius r.

B<Example:>

    my $tag = $SVG->circlecx=>4, cy=>2, r=>1);

=cut

=pod

=head2 ellipse

$tag = $SVG->ellipse(%attributes)

Draw an ellipse at (cx,cy) with radii rx,ry.

B<Example:>

    my $tag = $SVG->ellipse(
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

=cut

=pod

=head2 rectangle (alias: rect)

$tag = $SVG->rectangle(%attributes)

Draw a rectangle at (x,y) with width 'width' and height 'height' and side radii
'rx' and 'ry'.

B<Example:>

    $tag = $SVG->rectangle(
        x=>10, y=>20,
        width=>4, height=>5,
        rx=>5.2, ry=>2.4,
        id=>'rect_1'
    );

=cut

sub rectangle ($;@) {
    my ($self,%attrs)=@_;
        return $self->tag('rect',%attrs);
}

=pod

=head2 image

 $tag = $SVG->image(%attributes)

Draw an image at (x,y) with width 'width' and height 'height' linked to image
resource '-href'. See also L<"use">.

B<Example:>

    $tag = $SVG->image(
        x=>100, y=>100,
        width=>300, height=>200,
        '-href'=>"image.png", #may also embed SVG, e.g. "image.SVG"
        id=>'image_1'
    );

B<Output:>

    <image xlink:href="image.png" x="100" y="100" width="300" height="200"/>

=cut

sub image ($;@) {
    my ($self,%attrs)=@_;
    my $im=$self->tag('image',%attrs);
    $im->{'xlink:href'}=$attrs{-href} if(defined $attrs{-href});
    return $im;
}

=pod

=head2 use

$tag = $SVG->use(%attributes)

Retrieve the content from an entity within an SVG document and apply it at
(x,y) with width 'width' and height 'height' linked to image resource '-href'.

B<Example:>

    $tag = $SVG->use(
        x=>100, y=>100,
        width=>300, height=>200,
        '-href'=>"pic.SVG#image_1",
        id=>'image_1'
    );

B<Output:>

    <use xlink:href="pic.SVG#image_1" x="100" y="100" width="300" height="200"/>

According to the SVG specification, the 'use' element in SVG can point to a
single element within an external SVG file.

=cut

sub use ($;@) {
    my ($self,%attrs)=@_;
    my $u=$self->tag('use',%attrs);
    $u->{'xlink:href'}=$attrs{-href} if(defined $attrs{-href});
    return $u;
}

=pod

=head2 polygon

$tag = $SVG->polygon(%attributes)

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

=cut

=pod

=head2 polyline

$tag = $SVG->polyline(%attributes)

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

$tag = $SVG->line(%attributes)

Draw a straight line between two points (x1,y1) and (x2,y2).

B<Example:>

    my $tag = $SVG->line(
        id=>'l1',
        x1=>0, y1=>10,
        x2=>10, y2=>0
    );

To draw multiple connected lines, use L<"polyline">.

=head2 text

$text = $SVG->text(%attributes)->cdata();

$text_path = $SVG->text(-type=>'path');
$text_span = $text_path->text(-type=>'span')->cdata('A');
$text_span = $text_path->text(-type=>'span')->cdata('B');
$text_span = $text_path->text(-type=>'span')->cdata('C');


define the container for a text string to be drawn in the image.

B<Input:> 
    -type     = path type (path | polyline | polygon)
    -type     = text element type  (path | span | normal [default])

B<Example:>

    my $text1 = $SVG->text(
        id=>'l1', x=>10, y=>10
    )->cdata('hello, world');

    my $text2 = $SVG->text(
        id=>'l1', x=>10, y=>10, -cdata=>'hello, world');

    my $text = $SVG->text(
        id=>'tp', x=>10, y=>10 -type=>path)
        ->text(id=>'ts' -type=>'span')
        ->cdata('hello, world');

SEE ALSO:

    L<"desc">, L<"cdata">.

=cut

sub text ($;@) {
    my ($self,%attrs)=@_;
    my $pre = '';
    $pre = $attrs{-type} || 'std';
    my %get_pre = (std=>'text',
                   path=>'textPath',
                   span=>'tspan',);

    $pre = $get_pre{lc($pre)};
    my $text=$self->tag($pre,%attrs);
    $text->{'xlink:href'} = $attrs{-href} if(defined $attrs{-href});
       $text->{'target'} = $attrs{-target} if(defined $attrs{-target});
    return($text);
}

=pod

=head2 title

$tag = $SVG->title(%attributes)

Generate the title of the image.

B<Example:>

    my $tag = $SVG->title(id=>'document-title')->cdata('This is the title');

=cut

=pod

=head2 desc

$tag = $SVG->desc(%attributes)

Generate the description of the image.

B<Example:>

    my $tag = $SVG->desc(id=>'document-desc')->cdata('This is a description');

=head2 comment

$tag = $SVG->comment(@comments)

Generate the description of the image.

B<Example:>

    my $tag = $SVG->comment('comment 1','comment 2','comment 3');

=cut

sub comment ($;@) {
    my ($self,@text)=@_;
    my $tag = $self->tag('comment');
    $tag->{-comment} = [@text];
    return $tag;
}

=pod 

$tag = $SVG->pi(@pi)

Generate a set of processing instructions

B<Example:>

    my $tag = $SVG->pi('instruction one','instruction two','instruction three');

    returns: 
      <lt>?instruction one?<gt>
      <lt>?instruction two?<gt>
      <lt>?instruction three?<gt>

=cut


sub pi ($;@) {
    my ($self,@text)=@_;
    my $tag = $self->tag('pi');
    $tag->{-pi} = [@text];
    return $tag;
}

=pod

=head2 script

$tag = $SVG->script(%attributes)

Generate a script container for dynamic (client-side) scripting using
ECMAscript, Javascript or other compatible scripting language.

B<Example:>

    my $tag = $SVG->script(-type=>"text/ecmascript");

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

=cut

sub script($;@) {
    my ($self,%attrs)=@_;
       my $script = $self->tag('script',%attrs);
    $script->{'xlink:href'}=$attrs{-href} if(defined $attrs{-href});
    return $script;
}

=pod


=head2 path

$tag = $SVG->path(%attributes)

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

    $tag = $SVG->path(
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

$path = $SVG->get_path(%attributes)

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
    $points = $SVG->get_path(x=&gt\@x,y=&gt\@y,-relative=&gt1,-type=&gt'path');
 
    #add the path to the SVG document
    my $p = $SVG->path(%$path, style=>\%style_definition);

    #generate an closed path definition for a a polyline.
    $points = $SVG->get_path(
        x=>\@x,
        y=>\@y,
        -relative=>1,
        -type=>'polyline',
        -closed=>1
    ); # generate a closed path definition for a polyline

    # add the polyline to the SVG document
    $p = $SVG->polyline(%$points, id=>'pline1');

B<Aliases:> get_path set_path

=cut

sub get_path ($;@) {
    my ($self,%attrs) = @_;

    my $type = $attrs{-type} || 'path';
    my @x = @{$attrs{x}};
    my @y = @{$attrs{y}};
    my $points;
    # we need a path-like point string returned
    if (lc($type) eq 'path') {
        my $char = 'M';
        $char = ' m ' if (defined $attrs{-relative} && lc($attrs{-relative}));
        while (@x) {
            #scale each value
            my $x = shift @x;
            my $y = shift @y;
            #append the scaled value to the graph
            $points .= "$char $x $y ";
            $char = ' L ';
            $char = ' l ' if (defined $attrs{-relative}
                                && lc($attrs{-relative}));
        }
        $points .=  ' z ' if (defined $attrs{-closed} && lc($attrs{-closed}));
        my %out = (d => $points);
        return \%out;
    } elsif (lc($type) =~ /^poly/){
        while (@x) {
            #scale each value
            my $x = shift @x;
            my $y = shift @y;
            #append the scaled value to the graph
            $points .= "$x,$y ";
        }
    }
    my %out = (points=>$points);
    return \%out;
}

sub make_path ($;@) {
    my ($self,%attrs) = @_;
    return get_path(%attrs);
}

sub set_path ($;@) {
    my ($self,%attrs) = @_;
    return get_path(%attrs);
}

=pod

=head2 animate

$tag = $SVG->animate(%attributes)

Generate an SMIL animation tag. This is allowed within any nonempty tag. Refer\
to the W3C for detailed information on the subtleties of the animate SMIL
commands.

B<Inputs:> -method = Transform | Motion | Color

  my $an_ellipse = $SVG->ellipse(
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

=cut

sub animate ($;@) {
    my ($self,%attrs) = @_;
    my %rtr = %attrs;
    my $method = $rtr{'-method'}; # Set | Transform | Motion | Color

    $method = lc($method);

    # we do not want this to pollute the generation of the tag
    delete $rtr{-method};  #bug report from briac.

    my %animation_method = (
        transform=>'animateTransform',
        motion=>'animateMotion',
        color=>'animateColor',
        set=>'set',
        attribute=>'animate'
    );
    
    my $name = $animation_method{$method} || 'animate';
    
    #list of legal entities for each of the 5 methods of animations
    my %legal = (
        animate =>    
          qq§ begin dur  end  min  max  restart  repeatCount 
              repeatDur  fill  attributeType attributeName additive
              accumulate calcMode  values  keyTimes  keySplines
              from  to  by §,
        animateTransform =>    
          qq§ begin dur  end  min  max  restart  repeatCount
              repeatDur  fill  additive  accumulate calcMode  values
              keyTimes  keySplines  from  to  by calcMode path keyPoints
              rotate origin type attributeName attributeType §,
    	animateMotion =>    
          qq§ begin dur  end  min  max  restart  repeatCount
              repeatDur  fill  additive  accumulate calcMode  values
              to  by keyTimes keySplines  from  path  keyPoints
              rotate  origin §,
        animateColor =>    
          qq§ begin dur  end  min  max  restart  repeatCount
              repeatDur  fill  additive  accumulate calcMode  values
              keyTimes  keySplines  from  to  by §,
        set =>    
          qq§ begin dur  end  min  max  restart  repeatCount  repeatDur
              fill to §
    );

    foreach my $k (keys %rtr) {
        next if ($k =~ /\-/);

        if ($legal{$name} !~ /\b$k\b/) {
            $self->error("$name.$k" => "Illegal animation command");
        }
    }

    return $self->tag($name,%rtr);
}

=pod

=head2 group

$tag = $SVG->group(%attributes)

Define a group of objects with common properties. groups can have style,
animation, filters, transformations, and mouse actions assigned to them.

B<Example:>

    $tag = $SVG->group(
        id        => 'xvs000248',
        style     => {
            'font'      => [ qw( Arial Helvetica sans ) ],
            'font-size' => 10,
            'fill'      => 'red',
        },
        transform => 'rotate(-45)'
    );

=cut

sub group ($;@) {
    my ($self,%attrs)=@_;
    return $self->tag('g',%attrs);
}

=pod

=head2 defs

$tag = $SVG->defs(%attributes)

define a definition segment. A Defs requires children when defined using SVG.pm
B<Example:>

    $tag = $SVG->defs(id  =>  'def_con_one',);

=head2 style

$SVG->style(%styledef)

Sets/Adds style-definition for the following objects being created.

Style definitions apply to an object and all its children for all properties for
which the value of the property is not redefined by the child.

=cut

sub STYLE ($;@) {
    my ($self,%attrs)=@_;

    $self->{style}=$self->{style} || {};
    foreach my $k (keys %attrs) {
        $self->{style}->{$k}=$attrs{$k};
    }

    return $self;
}

=pod

=head2 mouseaction

$SVG->mouseaction(%attributes)

Sets/Adds mouse action definitions for tag

=cut

sub mouseaction ($;@) {
    my ($self,%attrs)=@_;

    $self->{mouseaction}=$self->{mouseaction} || {};
    foreach my $k (keys %attrs) {
        $self->{mouseaction}->{$k}=$attrs{$k};
    }

    return $self;
}

=pod

$SVG->attrib($name, $value)

Sets/Adds attributes of an element.

Retrieve an attribute:

    $svg->attrib($name);

Set a scalar attribute:

    $SVG->attrib $name, $value

Set a list attribute:

    $SVG->attrib $name, \@value

Set a hash attribute (i.e. style definitions):

    $SVG->attrib $name, \%value

Remove an attribute:

    $svg->attrib($name,undef);

B<Aliases:> attr attribute

=cut

sub attrib ($$;$) {
    my ($self,$name,$val)=@_;

    #verify that the current id is unique. compain on exception
    if ($name eq "id") {
        if ($self->getElementByID($val)) {
            $self->error($val => "ID already exists in document");
            return undef;
        }
    } 

    if (not defined $val) {
        if (scalar(@_)==2) {
            # two arguments only - retrieve
            return $self->{$name};
        } else {
            # 3rd argument is undef - delete
            delete $self->{$name};
        }
    } else {
        # 3 defined arguments - set
        $self->{$name}=$val;
    }

    return $self;
}
*attr=\&attrib;
*attribute=\&attrib;

=pod

=head2 cdata

$SVG->cdata($text)

Sets cdata to $text. SVG.pm allows you to set cdata for any tag. If the tag is
meant to be an empty tag, SVG.pm will not complain, but the rendering agent will
fail. In the SVG DTD, cdata is generally only meant for adding text or script
content.

B<Example:>

    $SVG->text(
        style => {
            'font'      => 'Arial',
            'font-size' => 20
        })->cdata('SVG.pm is a perl module on CPAN!');

    my $text = $SVG->text(style=>{'font'=>'Arial','font-size'=>20});
    $text->cdata('SVG.pm is a perl module on CPAN!');


B<Result:>

    E<lt>text style="font: Arial; font-size: 20" E<gt>SVG.pm is a perl module on CPAN!E<lt>/text E<gt>

SEE ALSO:

  L<"CDATA"> L<"desc">, L<"title">, L<"text">, L<"script">.

=cut

sub cdata ($@) {
    my ($self,@txt)=@_;
    $self->{-cdata}=join(' ',@txt);
    return($self);
}

=pod

=head2 CDATA

 $script = $SVG->script();
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
        $SVG->script()->CDATA($text);


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

=cut

sub CDATA ($@) {
    my ($self,@txt)=@_;
    $self->{-CDATA}=join('\n',@txt);
    return($self);
}

sub cdata_noxmlesc ($@) {
    my ($self,@txt)=@_;
    $self->{-cdata_noxmlesc}=join('\n',@txt);
    return($self);
}

=pod

=head2 filter

$tag = $SVG->filter(%attributes)

Generate a filter. Filter elements contain L<"fe"> filter sub-elements.

B<Example:>

    my $filter = $SVG->filter(
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

=cut

sub filter ($;@) {
    my ($self,%attrs)=@_;
    return $self->tag('filter',%attrs);
}

=pod

=head2 fe

$tag = $SVG->fe(-type=>'type', %attributes)

Generate a filter sub-element. Must be a child of a L<"filter"> element.

B<Example:>

    my $fe = $SVG->fe(
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

=cut

sub fe ($;@) {
    my ($self,%attrs) = @_;

    return 0 unless  ($attrs{'-type'});
    my %allowed = (
        blend => 'feBlend',
        colormatrix => 'feColorMatrix',
        componenttrans => 'feComponentTrans',
        composite => 'feComposite',
        convolvematrix => 'feConvolveMatrix',
        diffuselighting => 'feDiffuseLighting',
        displacementmap => 'feDisplacementMap',
        distantlight => 'feDistantLight',
        flood => 'feFlood',
        funca => 'feFuncA',
        funcb => 'feFuncB',
        funcg => 'feFuncG',
        funcr => 'feFuncR',
        gaussianblur => 'feGaussianBlur',
        image => 'feImage',
        merge => 'feMerge',
        mergenode => 'feMergeNode',
        morphology => 'feMorphology',
        offset => 'feOffset',
        pointlight => 'fePointLight',
        specularlighting => 'feSpecularLighting',
        spotlight => 'feSpotLight',
        tile => 'feTile',
        turbulence => 'feTurbulence'
    );

    my $key = lc($attrs{'-type'});
    my $fe_name = $allowed{$key} || 'error:illegal_filter_element';
    delete $attrs{'-type'};

    return $self->tag($fe_name, %attrs);
}

=pod

=head2 pattern

$tag = $SVG->pattern(%attributes)

Define a pattern for later reference by url.

B<Example:>

    my $pattern = $SVG->pattern(
        id     => "Argyle_1",
        width  => "50",
        height => "50",
        patternUnits        => "userSpaceOnUse",
        patternContentUnits => "userSpaceOnUse"
    );

=cut

sub pattern ($;@) {
    my ($self,%attrs)=@_;
    return $self->tag('pattern',%attrs);
}

=pod

=head2 set

$tag = $SVG->set(%attributes)

Set a definition for an SVG object in one section, to be referenced in other
sections as needed.

B<Example:>

    my $set = $SVG->set(
        id     => "Argyle_1",
        width  => "50",
        height => "50",
        patternUnits        => "userSpaceOnUse",
        patternContentUnits => "userSpaceOnUse"
    );

=cut

sub set ($;@) {
    my ($self,%attrs)=@_;
    return $self->tag('set',%attrs);
}

=pod

=head2 stop

$tag = $SVG->stop(%attributes)

Define a stop boundary for L<"gradient">

B<Example:>

   my $pattern = $SVG->stop(
       id     => "Argyle_1",
       width  => "50",
       height => "50",
       patternUnits        => "userSpaceOnUse",
       patternContentUnits => "userSpaceOnUse"
   );

=cut

sub stop ($;@) {
    my ($self,%attrs)=@_;
    return $self->tag('stop',%attrs);
}

=pod

$tag = $SVG->gradient(%attributes)

Define a color gradient. Can be of type B<linear> or B<radial>

B<Example:>

    my $gradient = $SVG->gradient(
        -type => "linear",
        id    => "gradient_1"
    );

=cut

sub gradient ($;@) {
    my ($self,%attrs)=@_;

    my $type = $attrs{'-type'} || 'linear';
    unless ($type =~ /^(linear|radial)$/) {
        $type = 'linear';
    }
    delete $attrs{'-type'};

    return $self->tag($type.'Gradient',%attrs);
}

=pod

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

=cut

#-------------------------------------------------------------------------------
# Internal methods

sub error ($$$) {
    my ($self,$command,$error)=@_;

    if ($self->{-docref}->{-raiseerror}) {
        die "$command: $error\n";
    } elsif ($self->{-docref}->{-printerror}) {
        print STDERR "$command: $error\n";
    }

    $self->{errors}{$command}=$error;
}

# This AUTOLOAD method is activated when '-auto' is passed to SVG.pm
sub autoload {
    my $self=shift;
    my ($package,$sub)=($AUTOLOAD=~/(.*)::([^:]+)$/);

    if ($sub eq 'DESTROY') {
        return $self->release();
    } else {
        # the import routine may call us with a tag name involving '-'s
        my $tag=$sub; $sub=~tr/-/_/;
        # N.B.: The \ on \@_ makes sure that the incoming arguments are
        # used and not the ones passed when the subroutine was created.
        eval "sub $package\:\:$sub (\$;\@) { return shift->tag('$tag',\@_) }";
        return $self->$sub(@_) if $self;
    }
}




#-------------------------------------------------------------------------------
# GD Routines

sub colorAllocate ($$$$) {
    my ($self,$red,$green,$blue)=@_;
    return 'rgb('.int($red).','.int($green).','.int($blue).')';
}

#-------------------------------------------------------------------------------

1;
