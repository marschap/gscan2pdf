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
use English qw( -no_match_vars );    # for $ERRNO
use Readonly;
Readonly my $CM_PER_INCH    => 2.54;
Readonly my $MM_PER_CM      => 10;
Readonly my $MM_PER_INCH    => $CM_PER_INCH * $MM_PER_CM;
Readonly my $PAGE_TOLERANCE => 0.02;
my $EMPTY         = q{};
my $SPACE         = q{ };
my $DOUBLE_QUOTES = q{"};

BEGIN {
    use Exporter ();
    our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

    $VERSION = '1.3.0';

    use base qw(Exporter);
    %EXPORT_TAGS = ();    # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw();
}
our @EXPORT_OK;

my ( $d, $logger );

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
    bless $new, ref $self;
    return $new;
}

# cloning File::Temp objects causes problems

sub freeze {
    my ($self) = @_;
    my $new = $self->clone;
    if ( ref( $new->{filename} ) eq 'File::Temp' ) {
        $new->{filename} = $self->{filename}->filename;
    }
    if ( ref( $new->{dir} ) eq 'File::Temp::Dir' ) {
        $new->{dir} = $self->{dir}->dirname;
    }
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
    return $new;
}

# returns array of boxes with OCR text

sub boxes {
    my ($self) = @_;

    # Unfortunately, there seems to be a case (tested in t/31_ocropus_utf8.t)
    # where decode_entities doesn't work cleanly, so encode/decode to finally
    # get good UTF-8
    my $hocr =
      decode_utf8(
        encode_utf8( HTML::Entities::decode_entities( $self->{hocr} ) ) );

    if ( $hocr =~ /<body>([\s\S]*)<\/body>/xsm ) {
        return _parse_hocr($hocr);
    }
    return {
        type => 'page',
        bbox => [ 0, 0, $self->{w}, $self->{h} ],
        text => $hocr
    };
}

sub _parse_hocr {
    my ($hocr) = @_;
    my $p = HTML::TokeParser->new( \$hocr );
    my ( $lineid, $wordid ) = ( 1, 1 );
    my ( %pagedata, %linedata, %worddata, $data, @boxes );
    while ( my $token = $p->get_token ) {
        given ( $token->[0] ) {
            when ('S') {
                my ( $tag, %attrs ) = ( $token->[1], %{ $token->[2] } );
                if ( $tag eq 'span' and defined $attrs{class} ) {
                    if ( _new_hocr_data(%attrs) ) {

                        # initialize data pointer
                        if ( $attrs{class} =~ /_word$/xsm ) {
                            %worddata       = %linedata;
                            $data           = \%worddata;
                            $data->{type}   = 'word';
                            $data->{lineid} = $linedata{id};
                            $data->{id}     = $wordid++;
                        }
                        else {
                            %linedata     = ();
                            $data         = \%linedata;
                            $data->{type} = 'line';
                            $data->{id}   = $lineid++;
                        }
                        _parse_tag_data( $attrs{title}, $data );
                    }
                    elsif ( $attrs{class} eq 'ocr_cinfo' ) {

                        # reset data pointer
                        undef $data;
                        %worddata = ();
                        %linedata = ();
                    }
                }
                if ( $tag eq 'div' and defined $attrs{class} ) {
                    if ( $attrs{class} =~ /_page$/xsm ) {
                        %pagedata     = ();
                        $data         = \%pagedata;
                        $data->{type} = 'page';
                        _parse_tag_data( $attrs{title}, $data );
                    }
                }
                elsif ( defined $data ) {
                    if ( $tag eq 'strong' ) { push @{ $data->{style} }, 'Bold' }
                    if ( $tag eq 'em' ) { push @{ $data->{style} }, 'Italic' }
                }
            }
            when ('T') {
                if ( $token->[1] !~ /^\s*$/xsm ) {
                    $data->{text} = $token->[1];
                    chomp $data->{text};
                }
            }
            when ('E') {

                # reset data pointer
                undef $data;
            }
        }

        if (    defined $data
            and defined $data->{bbox}
            and ( defined $data->{text} or $data->{type} eq 'page' ) )
        {
            push @boxes, { %{$data} };
            undef $data;
        }
    }
    return @boxes;
}

sub _new_hocr_data {
    my %attrs = @_;
    return (
        (
                 $attrs{class} eq 'ocr_line'
              or $attrs{class} eq 'ocr_word'
              or $attrs{class} eq 'ocrx_word'
        )
          and defined $attrs{title}
    );
}

sub _parse_tag_data {
    my ( $title, $data ) = @_;
    if ( $title =~ /\bbbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/xsm ) {
        $data->{bbox} = [ $1, $2, $3, $4 ];
    }
    if ( $title =~ /\btextangle\s+(\d+)/xsm ) { $data->{textangle}  = $1 }
    if ( $title =~ /\bx_wconf\s+(\d+)/xsm )   { $data->{confidence} = $1 }
    if ( $title =~ /\bbaseline\s+(?:-?\d+(?:[.]\d+)?\s+)*(-?\d+)/xsm ) {
        $data->{baseline} = $1;

        # slightly kludgy: textangle defined means 90°
        $data->{base} = $data->{baseline} + defined $data->{textangle}
          ? $data->{bbox}[3]    ## no critic (ProhibitMagicNumbers)
          : $data->{bbox}[2];
    }
    return;
}

sub djvu_text {
    my ($self) = @_;

    my $w          = $self->{w};
    my $h          = $self->{h};
    my $resolution = $self->{resolution};
    my $string     = $EMPTY;

    # Write the text boxes
    for my $box ( $self->boxes ) {
        my ( $x1, $y1, $x2, $y2 ) = @{ $box->{bbox} };
        if ( $box->{type} eq 'page' ) {
            ( $w, $h ) = ( $x2, $y2 );
            $string .= sprintf '(page %d %d %d %d', $x1, $y1, $x2, $y2;
            if ( defined $box->{text} ) {
                $string .= $SPACE . _escape_text( $box->{text} );
            }
        }
        else {
            if ( $x1 == 0 and $y1 == 0 and not defined $x2 ) {
                ( $x2, $y2 ) = ( $w * $resolution, $h * $resolution );
            }

            $string .= sprintf "\n($box->{type} %d %d %d %d %s)", $x1,
              $h - $y2, $x2,
              $h - $y1, _escape_text( $box->{text} );
        }
    }
    $string .= ")\n";
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
