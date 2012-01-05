package Gscan2pdf::Page;

use 5.008005;
use strict;
use warnings;
use Carp;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2;
use File::Copy;
use File::Temp;             # To create temporary files
use HTML::TokeParser;
use HTML::Entities;
use Image::Magick;
use Encode;

BEGIN {
 use Exporter ();
 our ( $VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );

 @ISA         = qw(Exporter);
 @EXPORT      = qw();
 %EXPORT_TAGS = ();             # eg: TAG => [ qw!name1 name2! ],

 # your exported package globals go here,
 # as well as any optionally exported functions
 @EXPORT_OK = qw();
}
our @EXPORT_OK;

sub new {
 my ( $class, %options ) = @_;
 my $self = {};
 croak "Error: filename not supplied" unless ( defined $options{filename} );
 croak "Error: format not supplied"   unless ( defined $options{format} );
 $main::logger->info(
  "New page filename $options{filename}, format $options{format}");
 for ( keys %options ) {
  $self->{$_} = $options{$_};
 }

 # get the resolution if necessary
 unless ( defined( $self->{resolution} ) ) {
  my $image = Image::Magick->new;
  my $x     = $image->Read( $options{filename} );
  $main::logger->warn($x) if "$x";
  $self->{resolution} = Gscan2pdf::Document::get_resolution($image);
 }

 # copy or move image to session directory
 my %suffix = (
  'Portable Network Graphics'                    => '.png',
  'Joint Photographic Experts Group JFIF format' => '.jpg',
  'Tagged Image File Format'                     => '.tif',
  'Portable anymap'                              => '.pnm',
  'CompuServe graphics interchange format'       => '.gif',
 );
 $self->{filename} = File::Temp->new(
  DIR    => $options{dir},
  SUFFIX => $suffix{ $options{format} },
  UNLINK => FALSE,
 );
 if ( defined( $options{delete} ) and $options{delete} ) {
  move( $options{filename}, $self->{filename} )
    or main::show_message_dialog( $main::window, 'error', 'close',
   $main::d->get('Error importing image: ') . $! );
 }
 else {
  copy( $options{filename}, $self->{filename} )
    or main::show_message_dialog( $main::window, 'error', 'close',
   $main::d->get('Error importing image: ') . $! );
 }

 bless( $self, $class );
 return $self;
}

sub clone {
 my ($self) = @_;
 my $new = {};
 for ( keys %{$self} ) {
  $new->{$_} = $self->{$_};
 }
 bless( $new, ref($self) );
 return $new;
}

# cloning File::Temp objects causes problems

sub freeze {
 my ($self) = @_;
 my $new = $self->clone;
 $new->{filename} = $self->{filename}->filename
   if ( ref( $new->{filename} ) eq 'File::Temp' );
 $new->{dir} = $self->{dir}->dirname
   if ( ref( $new->{dir} ) eq 'File::Temp::Dir' );
 return $new;
}

sub thaw {
 my ($self) = @_;
 my $new = $self->clone;
 my $suffix;
 $suffix = $1 if ( $new->{filename} =~ /\.(\w*)$/ );
 my $filename = File::Temp->new( DIR => $new->{dir}, SUFFIX => ".$suffix" );
 move( $new->{filename}, $filename );
 $new->{filename} = $filename;
 return $new;
}

# returns array of boxes with OCR text

sub boxes {
 my ( $self, @boxes ) = @_;

 if ( $self->{hocr} =~ /<body>([\s\S]*)<\/body>/ ) {
  my $p = HTML::TokeParser->new( \$self->{hocr} );
  my ( $x1, $y1, $x2, $y2, $text );
  while ( my $token = $p->get_token ) {
   if ( $token->[0] eq 'S' ) {
    if ( $token->[1] eq 'span'
     and defined( $token->[2]{class} )
     and
     ( $token->[2]{class} eq 'ocr_line' or $token->[2]{class} eq 'ocr_word' )
     and defined( $token->[2]{title} )
     and $token->[2]{title} =~ /bbox (\d+) (\d+) (\d+) (\d+)/ )
    {
     ( $x1, $y1, $x2, $y2 ) = ( $1, $2, $3, $4 );
    }
    elsif ( $token->[1] eq 'span'
     and defined( $token->[2]{class} )
     and $token->[2]{class} eq 'ocr_cinfo' )
    {
     undef $x1;
     undef $text;
    }
   }
   if ( $token->[0] eq 'T' and $token->[1] !~ /^\s*$/ ) {

    # Unfortunately, there seems to be a case (tested in t/31_ocropus_utf8.t)
    # where decode_entities doesn't work cleanly, so encode/decode to finally
    # get good UTF-8
    $text = decode_utf8( encode_utf8( HTML::Entities::decode_entities( $token->[1] ) ) );
    chomp($text);
   }
   if ( $token->[0] eq 'E' ) {
    undef $x1;
    undef $text;
   }
   push @boxes, [ $x1, $y1, $x2, $y2, $text ]
     if ( defined($x1) and defined($text) );
  }
 }
 else {
  push @boxes, [ 0, 0, $self->{w}, $self->{h}, decode_utf8( $self->{hocr} ) ];
 }
 return @boxes;
}

1;

__END__
