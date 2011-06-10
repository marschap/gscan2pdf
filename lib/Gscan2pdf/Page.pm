package Gscan2pdf::Page;

use 5.008005;
use strict;
use warnings;
use Carp;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2;
use File::Copy;
use File::Temp;             # To create temporary files

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
 $main::logger->info("Importing $options{filename}, format $options{format}");
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
    or show_message_dialog( $main::window, 'error', 'close',
   $main::d->get('Error importing image') );
 }
 else {
  copy( $options{filename}, $self->{filename} )
    or show_message_dialog( $main::window, 'error', 'close',
   $main::d->get('Error importing image') );
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

1;

__END__
