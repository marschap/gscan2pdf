package Gscan2pdf::Page;

use 5.008005;
use strict;
use warnings;
use feature 'switch';
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use Carp;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use File::Copy;
use File::Temp;             # To create temporary files
use HTML::TokeParser;
use HTML::Entities;
use Image::Magick;
use Encode;
use Locale::gettext 1.05;    # For translations
use POSIX qw(locale_h);
use Data::UUID;
use Text::Balanced qw ( extract_bracketed );
use English qw( -no_match_vars );    # for $ERRNO
use Gscan2pdf::Document;
use Readonly;
Readonly my $CM_PER_INCH    => 2.54;
Readonly my $MM_PER_CM      => 10;
Readonly my $MM_PER_INCH    => $CM_PER_INCH * $MM_PER_CM;
Readonly my $PAGE_TOLERANCE => 0.02;
Readonly my $EMPTY_LIST     => -1;
Readonly my $HALF           => 0.5;
my $EMPTY         = q{};
my $SPACE         = q{ };
my $DOUBLE_QUOTES = q{"};

BEGIN {
    use Exporter ();
    our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

    $VERSION = '1.8.0';

    use base qw(Exporter);
    %EXPORT_TAGS = ();    # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw();
}
our @EXPORT_OK;

my ( $d, $logger );
my $uuid = Data::UUID->new;

sub new {
    my ( $class, %options ) = @_;
    my $self = {};
    if ( not defined $d ) {
        $d = Locale::gettext->domain(Glib::get_application_name);
    }

    if ( not defined $options{filename} ) {
        croak 'Error: filename not supplied';
    }
    if ( not -f $options{filename} ) { croak 'Error: filename not found' }
    if ( not defined $options{format} ) {
        croak 'Error: format not supplied';
    }

    $logger->info(
        "New page filename $options{filename}, format $options{format}");
    for ( keys %options ) {
        $self->{$_} = $options{$_};
    }
    $self->{uuid} = $uuid->create_str();

    # copy or move image to session directory
    my %suffix = (
        'Portable Network Graphics'                    => '.png',
        'Joint Photographic Experts Group JFIF format' => '.jpg',
        'Tagged Image File Format'                     => '.tif',
        'Portable anymap'                              => '.pnm',
        'Portable pixmap format (color)'               => '.ppm',
        'Portable graymap format (gray scale)'         => '.pgm',
        'Portable bitmap format (black and white)'     => '.pbm',
        'CompuServe graphics interchange format'       => '.gif',
    );
    $self->{filename} = File::Temp->new(
        DIR    => $options{dir},
        SUFFIX => $suffix{ $options{format} },
        UNLINK => FALSE,
    );
    if ( defined $options{delete} and $options{delete} ) {
        move( $options{filename}, $self->{filename} )
          or croak sprintf $d->get('Error importing image %s: %s'),
          $options{filename}, $ERRNO;
    }
    else {
        copy( $options{filename}, $self->{filename} )
          or croak sprintf $d->get('Error importing image %s: %s'),
          $options{filename}, $ERRNO;
    }

    bless $self, $class;
    return $self;
}

sub set_logger {
    ( my $class, $logger ) = @_;
    return;
}

sub clone {
    my ( $self, $copy_image ) = @_;
    my $new = {};
    for ( keys %{$self} ) {
        $new->{$_} = $self->{$_};
    }
    $new->{uuid} = $uuid->create_str();
    if ($copy_image) {
        my $suffix;
        if ( $self->{filename} =~ /([.]\w*)$/xsm ) { $suffix = $1 }
        $new->{filename} =
          File::Temp->new( DIR => $self->{dir}, SUFFIX => $suffix );
        $logger->info("Cloning $self->{filename} -> $new->{filename}");

        # stringify filename to prevent copy from mangling it
        copy( "$self->{filename}", "$new->{filename}" )
          or croak sprintf $d->get('Error copying image %s: %s'),
          $self->{filename}, $ERRNO;
    }
    bless $new, ref $self;
    return $new;
}

# cloning File::Temp objects causes problems

sub freeze {
    my ($self) = @_;
    my $new = $self->clone;
    if ( ref( $new->{filename} ) eq 'File::Temp' ) {
        $new->{filename}->unlink_on_destroy(FALSE);
        $new->{filename} = $self->{filename}->filename;
    }
    if ( ref( $new->{dir} ) eq 'File::Temp::Dir' ) {
        $new->{dir} = $self->{dir}->dirname;
    }
    $new->{uuid} = $self->{uuid};
    return $new;
}

sub thaw {
    my ($self) = @_;
    my $new = $self->clone;
    my $suffix;
    if ( $new->{filename} =~ /[.](\w*)$/xsm ) {
        $suffix = $1;
    }
    my $filename = File::Temp->new( DIR => $new->{dir}, SUFFIX => ".$suffix" );
    move( $new->{filename}, $filename );
    $new->{filename} = $filename;
    $new->{uuid}     = $self->{uuid};
    return $new;
}

# returns array of boxes with OCR text

sub boxes {
    my ($self) = @_;
    my $hocr = $self->{hocr};
    if ( $hocr =~ /<body>([\s\S]*)<\/body>/xsm ) {
        my $boxes = _hocr2boxes($hocr);
        _prune_empty_branches($boxes);
        return $boxes;
    }
    return [
        {
            type => 'page',
            bbox => [ 0, 0, $self->{w}, $self->{h} ],
            text => _decode_hocr($hocr)
        }
    ];
}

# Unfortunately, there seems to be a case (tested in t/31_ocropus_utf8.t)
# where decode_entities doesn't work cleanly, so encode/decode to finally
# get good UTF-8

sub _decode_hocr {
    my ($hocr) = @_;
    return decode_utf8( encode_utf8( HTML::Entities::decode_entities($hocr) ) );
}

sub _hocr2boxes {
    my ($hocr) = @_;
    my $p = HTML::TokeParser->new( \$hocr );
    my ( $data, @stack, $boxes );
    while ( my $token = $p->get_token ) {
        given ( $token->[0] ) {
            when ('S') {
                my ( $tag, %attrs ) = ( $token->[1], %{ $token->[2] } );

                # new data point
                $data = {};

                if ( defined $attrs{class} and defined $attrs{title} ) {
                    _parse_tag_data( $attrs{title}, $data );
                    given ( $attrs{class} ) {
                        when (/_page$/xsm) {
                            $data->{type} = 'page';
                            push @{$boxes}, $data;
                        }
                        when (/_carea$/xsm) {
                            $data->{type} = 'column';
                        }
                        when (/_par$/xsm) {
                            $data->{type} = 'para';
                        }
                        when (/_line$/xsm) {
                            $data->{type} = 'line';
                        }
                        when (/_word$/xsm) {
                            $data->{type} = 'word';
                        }
                    }

                    # pick up previous pointer to add style
                    if ( not defined $data->{type} ) {
                        $data = $stack[-1];
                    }

                    # put information xocr_word information in parent ocr_word
                    if (    $data->{type} eq 'word'
                        and $stack[-1]{type} eq 'word' )
                    {
                        for ( keys %{$data} ) {
                            if ( not defined $stack[-1]{$_} ) {
                                $stack[-1]{$_} = $data->{$_};
                            }
                            elsif ( $_ ne 'type' ) {
                                $logger->warn("Ignoring $_=$data->{$_}");
                            }
                        }

                        # pick up previous pointer to add any later text
                        $data = $stack[-1];
                    }
                    else {
                        if ( defined $attrs{id} ) {
                            $data->{id} = $attrs{id};
                        }

                        # if we have previous data, add the new data to the
                        # contents of the previous data point
                        if (    defined $stack[-1]
                            and $data != $stack[-1]
                            and defined $data->{bbox} )
                        {
                            push @{ $stack[-1]{contents} }, $data;
                        }
                    }
                }

                # pick up previous pointer
                # so that unknown tags don't break the chain
                else {
                    $data = $stack[-1];
                }
                if ( defined $data ) {
                    if ( $tag eq 'strong' ) { push @{ $data->{style} }, 'Bold' }
                    if ( $tag eq 'em' ) { push @{ $data->{style} }, 'Italic' }
                }

                # put the new data point on the stack
                push @stack, $data;
            }
            when ('T') {
                if ( $token->[1] !~ /^\s*$/xsm ) {
                    $data->{text} = _decode_hocr( $token->[1] );
                    chomp $data->{text};
                }
            }
            when ('E') {

                # up a level
                $data = pop @stack;
            }
        }

    }
    return $boxes;
}

sub _parse_tag_data {
    my ( $title, $data ) = @_;
    if ( $title =~ /\bbbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/xsm ) {
        if ( $1 != $3 and $2 != $4 ) { $data->{bbox} = [ $1, $2, $3, $4 ] }
    }
    if ( $title =~ /\btextangle\s+(\d+)/xsm ) { $data->{textangle}  = $1 }
    if ( $title =~ /\bx_wconf\s+(-?\d+)/xsm ) { $data->{confidence} = $1 }
    if ( $title =~ /\bbaseline\s+((?:-?\d+(?:[.]\d+)?\s+)*-?\d+)/xsm ) {
        my @values = split /\s+/sm, $1;

        # make sure we at least have 2 coefficients
        if ( $#values <= 0 ) { unshift @values, 0; }
        $data->{baseline} = \@values;
    }
    return;
}

sub _prune_empty_branches {
    my ($boxes) = @_;
    if ( defined $boxes ) {
        my $i = 0;
        while ( $i <= $#{$boxes} ) {
            my $child = $boxes->[$i];
            _prune_empty_branches( $child->{contents} );
            if ( $#{ $child->{contents} } == $EMPTY_LIST ) {
                delete $child->{contents};
            }
            if ( $#{$boxes} > $EMPTY_LIST
                and not( defined $child->{contents} or defined $child->{text} )
              )
            {
                splice @{$boxes}, $i, 1;
            }
            else {
                $i++;
            }
        }
    }
    return;
}

sub _pdftotext2boxes {
    my ( $self, $html ) = @_;
    my $p = HTML::TokeParser->new( \$html );
    my ( $data, @stack, $boxes );
    while ( my $token = $p->get_token ) {
        given ( $token->[0] ) {
            when ('S') {
                my ( $tag, %attrs ) = ( $token->[1], %{ $token->[2] } );

                # new data point
                $data = {};

                if ( $tag eq 'page' ) {
                    $data->{type} = $tag;
                    if ( defined $attrs{width} and defined $attrs{height} ) {
                        $data->{bbox} = [
                            0, 0,
                            scale( $attrs{width},  $self->resolution ),
                            scale( $attrs{height}, $self->resolution )
                        ];
                    }
                    push @{$boxes}, $data;
                }
                elsif ( $tag eq 'word' ) {
                    $data->{type} = $tag;
                    if (    defined $attrs{xmin}
                        and defined $attrs{ymin}
                        and defined $attrs{xmax}
                        and defined $attrs{ymax} )
                    {
                        $data->{bbox} = [
                            scale( $attrs{xmin}, $self->resolution ),
                            scale( $attrs{ymin}, $self->resolution ),
                            scale( $attrs{xmax}, $self->resolution ),
                            scale( $attrs{ymax}, $self->resolution )
                        ];
                    }
                }

                # if we have previous data, add the new data to the
                # contents of the previous data point
                if (    defined $stack[-1]
                    and $data != $stack[-1]
                    and defined $data->{bbox} )
                {
                    push @{ $stack[-1]{contents} }, $data;
                }

                # put the new data point on the stack
                if ( defined $data->{bbox} ) { push @stack, $data }
            }
            when ('T') {
                if ( $token->[1] !~ /^\s*$/xsm ) {
                    $data->{text} = _decode_hocr( $token->[1] );
                    chomp $data->{text};
                }
            }
            when ('E') {

                # up a level
                $data = pop @stack;
            }
        }

    }
    return $boxes;
}

sub scale {
    my ( $f, $resolution ) = @_;
    return
      int( $f * $resolution / $Gscan2pdf::Document::POINTS_PER_INCH + $HALF );
}

# return hocr output as string

sub string {
    my ($self) = @_;
    return _boxes2string( $self->boxes );
}

sub _boxes2string {
    my ($boxes) = @_;
    my $string = $EMPTY;

    # Note y value to be able to put line breaks
    # at appropriate positions
    my ( $oldx, $oldy );
    for my $box ( @{$boxes} ) {
        if ( defined $box->{contents} ) {
            $string .= _boxes2string( $box->{contents} );
        }
        if ( not defined $box->{text} ) { next }
        my ( $x1, $y1, $x2, $y2 ) = @{ $box->{bbox} };
        if ( defined $oldx and $x1 > $oldx ) { $string .= $SPACE }
        if ( defined $oldy and $y1 > $oldy ) { $string .= "\n" }
        ( $oldx, $oldy ) = ( $x1, $y1 );
        $string .= $box->{text};
    }
    return $string;
}

sub djvu_text {
    my ($self) = @_;
    my $boxes = $self->boxes;
    if ( defined $boxes and $#{$boxes} > $EMPTY_LIST ) {
        my $h =
          ( $boxes->[0]{type} eq 'page' ) ? $boxes->[0]{bbox}[-1] : $self->{h};
        return _boxes2djvu( $boxes, 0, $h );
    }
    return $EMPTY;
}

sub _boxes2djvu {
    my ( $pointer, $indent, $h ) = @_;
    my $string = $EMPTY;

    # Write the text boxes
    for my $box ( @{$pointer} ) {
        my ( $x1, $y1, $x2, $y2 ) = @{ $box->{bbox} };
        if ( $indent != 0 ) { $string .= "\n" }
        for ( 1 .. $indent ) { $string .= $SPACE }
        $string .= sprintf "($box->{type} %d %d %d %d", $x1, $h - $y2, $x2,
          $h - $y1;
        if ( defined $box->{text} ) {
            $string .= $SPACE . _escape_text( $box->{text} );
        }
        if ( defined $box->{contents} ) {
            $string .= _boxes2djvu( $box->{contents}, $indent + 2, $h );
        }
        $string .= ')';
    }
    if ( $indent == 0 ) { $string .= "\n" }
    return $string;
}

sub _boxes2hocr {
    my ( $pointer, $indent ) = @_;
    my $string = $EMPTY;
    if ( not defined $indent ) { $indent = 0 }

    # Write the text boxes
    for my $box ( @{$pointer} ) {
        my ( $x1, $y1, $x2, $y2 ) = @{ $box->{bbox} };
        if ( $indent == 0 ) {
            $string .= <<'EOS';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf 1.4.0' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
EOS
        }
        else {
            $string .= "\n";
        }
        for ( 0 .. $indent + 1 ) { $string .= $SPACE }
        my $type  = $box->{type};
        my $class = 'span';
        given ( $box->{type} ) {
            when ('page') {
                $class = 'div';
            }
            when ('column') {
                $type  = 'carea';
                $class = 'div';
            }
            when ('para') {
                $type  = 'par';
                $class = 'p';
            }
        }
        $string .=
          sprintf "<$class class='ocr_$type' title=\"bbox %d %d %d %d\">", $x1,
          $y1, $x2, $y2;
        if ( defined $box->{text} ) {
            $string .= $box->{text};
        }
        if ( defined $box->{contents} ) {
            $string .= _boxes2hocr( $box->{contents}, $indent + 1 ) . "\n";
            for ( 0 .. $indent + 1 ) { $string .= $SPACE }
            $string .= "</$class>";
        }
        else {
            $string .= "</$class>";
        }
    }
    if ( $indent == 0 ) { $string .= "\n </body>\n</html>\n" }
    return $string;
}

sub _djvu2boxes {
    my ( $text, $h ) = @_;
    my @boxes;
    while ( defined $text and $text !~ /\A\s*\z/xsm ) {
        my @result = extract_bracketed( $text, '(")' );
        if ( not defined $result[0] ) {
            croak "Error parsing brackets in $text";
        }
        if ( $result[0] =~
            /^\s*[(](\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.*)[)]$/xsm )
        {
            my $box = {};
            $box->{type} = $1;
            if ( $1 eq 'page' ) { $h = $5 }
            $box->{bbox} = [ $2, $h - $5, $4, $h - $3 ];
            my $rest = $6;
            if ( $rest =~ /\A\s*[(].*[)]\s*\z/xsm ) {
                $box->{contents} = _djvu2boxes( $rest, $h );
            }
            elsif ( $rest =~ /\A\s*"(.*)"\s*\z/xsm ) {
                $box->{text} = $1;
            }
            else {
                croak "Error parsing djvu text $rest";
            }
            push @boxes, $box;
        }
        else {
            croak "Error parsing djvu text $result[0]";
        }
        $text = $result[1];
    }
    return \@boxes;
}

sub import_djvutext {
    my ( $self, $text ) = @_;
    my $boxes = _djvu2boxes($text);
    $self->{hocr} = _boxes2hocr($boxes);
    return;
}

sub import_pdftotext {
    my ( $self, $html ) = @_;
    my $boxes = $self->_pdftotext2boxes($html);
    $self->{hocr} = _boxes2hocr($boxes);
    return;
}

# Escape backslashes and inverted commas
# Surround with inverted commas
sub _escape_text {
    my ($txt) = @_;
    $txt =~ s/\\/\\\\/gxsm;
    $txt =~ s/"/\\\"/gxsm;
    return "$DOUBLE_QUOTES$txt$DOUBLE_QUOTES";
}

sub to_png {
    my ( $self, $page_sizes ) = @_;

    # Write the png
    my $png =
      File::Temp->new( DIR => $self->{dir}, SUFFIX => '.png', UNLINK => FALSE );
    $self->im_object->Write(
        units    => 'PixelsPerInch',
        density  => $self->resolution($page_sizes),
        filename => $png
    );
    my $new = Gscan2pdf::Page->new(
        filename   => $png,
        format     => 'Portable Network Graphics',
        dir        => $self->{dir},
        resolution => $self->resolution($page_sizes),
    );
    if ( defined $self->{hocr} ) { $new->{hocr} = $self->{hocr} }
    return $new;
}

sub resolution {
    my ( $self, $paper_sizes ) = @_;
    return $self->{resolution} if defined $self->{resolution};
    my $image  = $self->im_object;
    my $format = $image->Get('format');
    setlocale( LC_NUMERIC, 'C' );

    if ( defined $self->{size} ) {
        my $width  = $image->Get('width');
        my $height = $image->Get('height');
        $logger->debug("PDF size @{$self->{size}}");
        $logger->debug("image size $width $height");
        my $scale = $Gscan2pdf::Document::POINTS_PER_INCH;
        if ( $self->{size}[2] ne 'pts' ) {
            croak "Error: unknown units '$self->{size}[2]'";
        }
        my $xres = $width / $self->{size}[0] * $scale;
        my $yres = $height / $self->{size}[1] * $scale;
        $logger->debug("resolution $xres $yres");
        if ( abs( $xres - $yres ) / $yres < $PAGE_TOLERANCE ) {
            $self->{resolution} = ( $xres + $yres ) / 2;
            return $self->{resolution};
        }
    }

    # Imagemagick always reports PNMs as 72ppi
    # Some versions of imagemagick report colour PNM as Portable pixmap (PPM)
    # B&W are Portable anymap
    if ( $format !~ /^Portable[ ]...map/xsm ) {
        $self->{resolution} = $image->Get('x-resolution');

        if ( not defined $self->{resolution} ) {
            $self->{resolution} = $image->Get('y-resolution');
        }

        if ( $self->{resolution} ) {
            my $units = $image->Get('units');
            if ( $units eq 'pixels / centimeter' ) {
                $self->{resolution} *= $CM_PER_INCH;
            }
            elsif ( $units =~ /undefined/xsm ) {
                $logger->warn('Undefined units.');
            }
            elsif ( $units ne 'pixels / inch' ) {
                $logger->warn("Unknown units: '$units'.");
                $units = 'undefined';
            }
            if ( $units =~ /undefined/xsm ) {
                $logger->warn(
                    'The resolution and page size will probably be wrong.');
            }
            return $self->{resolution};
        }
    }

    # Return the first match based on the format
    for ( values %{ $self->matching_paper_sizes($paper_sizes) } ) {
        $self->{resolution} = $_;
        return $self->{resolution};
    }

    # Default to 72
    $self->{resolution} = $Gscan2pdf::Document::POINTS_PER_INCH;
    return $self->{resolution};
}

# Given paper width and height (mm), and hash of paper sizes,
# returns hash of matching resolutions (pixels per inch)

sub matching_paper_sizes {
    my ( $self, $paper_sizes ) = @_;
    if ( not( defined $self->{height} and defined $self->{width} ) ) {
        my $image = $self->im_object;
        $self->{width}  = $image->Get('width');
        $self->{height} = $image->Get('height');
    }
    my $ratio = $self->{height} / $self->{width};
    if ( $ratio < 1 ) { $ratio = 1 / $ratio }
    my %matching;
    for ( keys %{$paper_sizes} ) {
        if ( $paper_sizes->{$_}{x} > 0
            and abs( $ratio - $paper_sizes->{$_}{y} / $paper_sizes->{$_}{x} ) <
            $PAGE_TOLERANCE )
        {
            $matching{$_} = (
                ( $self->{height} > $self->{width} )
                ? $self->{height}
                : $self->{width}
              ) /
              $paper_sizes->{$_}{y} *
              $MM_PER_INCH;
        }
    }
    return \%matching;
}

# returns Image::Magick object

sub im_object {
    my ($self) = @_;
    my $image  = Image::Magick->new;
    my $x      = $image->Read( $self->{filename} );
    if ("$x") { $logger->warn($x) }
    return $image;
}

1;

__END__
