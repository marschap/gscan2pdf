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
use Locale::gettext 1.05;            # For translations
use POSIX qw(locale_h);
use Data::UUID;
use English qw( -no_match_vars );    # for $ERRNO
use Readonly;
Readonly my $CM_PER_INCH    => 2.54;
Readonly my $MM_PER_CM      => 10;
Readonly my $MM_PER_INCH    => $CM_PER_INCH * $MM_PER_CM;
Readonly my $PAGE_TOLERANCE => 0.02;
Readonly my $EMPTY_LIST     => -1;
my $EMPTY         = q{};
my $SPACE         = q{ };
my $DOUBLE_QUOTES = q{"};

BEGIN {
    use Exporter ();
    our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

    $VERSION = '1.3.5';

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
    my ($self) = @_;
    my $new = {};
    for ( keys %{$self} ) {
        $new->{$_} = $self->{$_};
    }
    $new->{uuid} = $uuid->create_str();
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
        my $boxes = _parse_hocr($hocr);
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

sub _parse_hocr {
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
    if ( $title =~ /\bbaseline\s+(?:-?\d+(?:[.]\d+)?\s+)*(-?\d+)/xsm ) {
        $data->{baseline} = $1;

        # slightly kludgy: textangle defined means 90°
        $data->{base} = $data->{baseline} + defined $data->{textangle}
          ? $data->{bbox}[3]    ## no critic (ProhibitMagicNumbers)
          : $data->{bbox}[2];
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
    return $new;
}

sub resolution {
    my ( $self, $paper_sizes ) = @_;
    return $self->{resolution} if defined $self->{resolution};
    my $image  = $self->im_object;
    my $format = $image->Get('format');
    setlocale( LC_NUMERIC, 'C' );

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
