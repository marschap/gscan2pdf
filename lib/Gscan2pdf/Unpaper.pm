package Gscan2pdf::Unpaper;

use 5.008005;
use strict;
use warnings;
use Carp;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;

BEGIN {
 use Exporter ();
 our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

 use base qw(Exporter);
 %EXPORT_TAGS = ();         # eg: TAG => [ qw!name1 name2! ],

 # your exported package globals go here,
 # as well as any optionally exported functions
 @EXPORT_OK = qw();
}
our @EXPORT_OK;

# Window parameters
my $border_width = 6;

sub new {
 my ( $class, $default ) = @_;
 my $self = {};
 $self->{default} = $default;

 # Set up hash for options
 $self->{options} = {
  layout => {
   type    => 'ComboBox',
   string  => $main::d->get('Layout'),
   options => {
    single => {
     string => $main::d->get('Single'),
     tooltip =>
       $main::d->get('One page per sheet, oriented upwards without rotation.'),
    },
    double => {
     string  => $main::d->get('Double'),
     tooltip => $main::d->get(
'Two pages per sheet, landscape orientation (one page on the left half, one page on the right half).'
     ),
    },
   },
   default => 'single',
  },
  'output-pages' => {
   type    => 'SpinButton',
   string  => $main::d->get('# Output pages'),
   tooltip => $main::d->get('Number of pages to output.'),
   min     => 1,
   max     => 2,
   step    => 1,
   default => 1,
  },
  'no-deskew' => {
   type    => 'CheckButton',
   string  => $main::d->get('No deskew'),
   tooltip => $main::d->get('Disable deskewing.'),
   default => FALSE,
  },
  'no-mask-scan' => {
   type    => 'CheckButton',
   string  => $main::d->get('No mask scan'),
   tooltip => $main::d->get('Disable mask detection.'),
   default => FALSE,
  },
  'no-blackfilter' => {
   type    => 'CheckButton',
   string  => $main::d->get('No black filter'),
   tooltip => $main::d->get('Disable black area scan.'),
   default => FALSE,
  },
  'no-grayfilter' => {
   type    => 'CheckButton',
   string  => $main::d->get('No gray filter'),
   tooltip => $main::d->get('Disable gray area scan.'),
   default => FALSE,
  },
  'no-noisefilter' => {
   type    => 'CheckButton',
   string  => $main::d->get('No noise filter'),
   tooltip => $main::d->get('Disable noise filter.'),
   default => FALSE,
  },
  'no-blurfilter' => {
   type    => 'CheckButton',
   string  => $main::d->get('No blur filter'),
   tooltip => $main::d->get('Disable blur filter.'),
   default => FALSE,
  },
  'no-border-scan' => {
   type    => 'CheckButton',
   string  => $main::d->get('No border scan'),
   tooltip => $main::d->get('Disable border scanning.'),
   default => FALSE,
  },
  'no-border-align' => {
   type   => 'CheckButton',
   string => $main::d->get('No border align'),
   tooltip =>
     $main::d->get('Disable aligning of the area detected by border scanning.'),
   default => FALSE,
  },
  'deskew-scan-direction' => {
   type    => 'CheckButtonGroup',
   string  => $main::d->get('Deskew to edge'),
   tooltip => $main::d->get(
"Edges from which to scan for rotation. Each edge of a mask can be used to detect the mask's rotation. If multiple edges are specified, the average value will be used, unless the statistical deviation exceeds --deskew-scan-deviation."
   ),
   options => {
    left => {
     type    => 'CheckButton',
     string  => $main::d->get('Left'),
     tooltip => $main::d->get("Use 'left' for scanning from the left edge."),
    },
    top => {
     type    => 'CheckButton',
     string  => $main::d->get('Top'),
     tooltip => $main::d->get("Use 'top' for scanning from the top edge."),
    },
    right => {
     type    => 'CheckButton',
     string  => $main::d->get('Right'),
     tooltip => $main::d->get("Use 'right' for scanning from the right edge."),
    },
    bottom => {
     type    => 'CheckButton',
     string  => $main::d->get('Bottom'),
     tooltip => $main::d->get("Use 'bottom' for scanning from the bottom."),
    },
   },
   default => 'left,right',
  },
  'border-align' => {
   type    => 'CheckButtonGroup',
   string  => $main::d->get('Align to edge'),
   tooltip => $main::d->get('Edge to which to align the page.'),
   options => {
    left => {
     type    => 'CheckButton',
     string  => $main::d->get('Left'),
     tooltip => $main::d->get("Use 'left' to align to the left edge."),
    },
    top => {
     type    => 'CheckButton',
     string  => $main::d->get('Top'),
     tooltip => $main::d->get("Use 'top' to align to the top edge."),
    },
    right => {
     type    => 'CheckButton',
     string  => $main::d->get('Right'),
     tooltip => $main::d->get("Use 'right' to align to the right edge."),
    },
    bottom => {
     type    => 'CheckButton',
     string  => $main::d->get('Bottom'),
     tooltip => $main::d->get("Use 'bottom' to align to the bottom."),
    },
   },
  },
  'border-margin' => {
   type    => 'SpinButtonGroup',
   string  => $main::d->get('Border margin'),
   options => {
    vertical => {
     type    => 'SpinButton',
     string  => $main::d->get('Vertical margin'),
     tooltip => $main::d->get(
'Vertical distance to keep from the sheet edge when aligning a border area.'
     ),
     min   => 0,
     max   => 1000,
     step  => 1,
     order => 0,
    },
    horizontal => {
     type    => 'SpinButton',
     string  => $main::d->get('Horizontal margin'),
     tooltip => $main::d->get(
'Horizontal distance to keep from the sheet edge when aligning a border area.'
     ),
     min   => 0,
     max   => 1000,
     step  => 1,
     order => 1,
    },
   },
  },
  'white-threshold' => {
   type   => 'SpinButton',
   string => $main::d->get('White threshold'),
   tooltip =>
     $main::d->get('Brightness ratio above which a pixel is considered white.'),
   min     => 0,
   max     => 1,
   step    => .01,
   default => 0.9,
  },
  'black-threshold' => {
   type    => 'SpinButton',
   string  => $main::d->get('Black threshold'),
   tooltip => $main::d->get(
'Brightness ratio below which a pixel is considered black (non-gray). This is used by the gray-filter. This value is also used when converting a grayscale image to black-and-white mode.'
   ),
   min     => 0,
   max     => 1,
   step    => .01,
   default => 0.33,
  },
 };
 bless( $self, $class );
 return $self;
}

sub add_options {
 my ( $self, $vbox ) = @_;
 my $options = $self->{options};

 # Layout ComboBox
 my $combobl  = $self->add_widget( $vbox, $options, 'layout' );
 my $outpages = $self->add_widget( $vbox, $options, 'output-pages' );
 $combobl->signal_connect(
  changed => sub {
   if ( $combobl->get_active == 0 ) {
    $outpages->set_range( 1, 2 );
   }
   else {
    $outpages->set_range( 1, 1 );
   }
  }
 );

 # Notebook to collate options
 my $notebook = Gtk2::Notebook->new;
 $vbox->pack_start( $notebook, TRUE, TRUE, 0 );

 # Notebook page 1
 my $vbox1 = Gtk2::VBox->new;
 $notebook->append_page( $vbox1, $main::d->get('Deskew') );

 my $dsbutton = $self->add_widget( $vbox1, $options, 'no-deskew' );

 # Frame for Deskew Scan Direction
 my $dframe = $self->add_widget( $vbox1, $options, 'deskew-scan-direction' );
 $dsbutton->signal_connect(
  toggled => sub {
   if ( $dsbutton->get_active ) {
    $dframe->set_sensitive(FALSE);
   }
   else {
    $dframe->set_sensitive(TRUE);
   }
  }
 );

 foreach ( keys %{ $options->{'deskew-scan-direction'}{options} } ) {
  my $button = $options->{'deskew-scan-direction'}{options}{$_}{widget};

  # Ensure that at least one checkbutton stays active
  $button->signal_connect(
   toggled => sub {
    $button->set_active(TRUE) if ( count_active_children($dframe) == 0 );
   }
  );
 }

 # Notebook page 2
 my $vbox2 = Gtk2::VBox->new;
 $notebook->append_page( $vbox2, $main::d->get('Border') );

 my $bsbutton = $self->add_widget( $vbox2, $options, 'no-border-scan' );
 my $babutton = $self->add_widget( $vbox2, $options, 'no-border-align' );

 # Frame for Align Border
 my $bframe = $self->add_widget( $vbox2, $options, 'border-align' );
 $bsbutton->signal_connect(
  toggled => sub {
   if ( $bsbutton->get_active ) {
    $bframe->set_sensitive(FALSE);
    $babutton->set_sensitive(FALSE);
   }
   else {
    $babutton->set_sensitive(TRUE);
    $bframe->set_sensitive(TRUE) if ( !( $babutton->get_active ) );
   }
  }
 );
 $babutton->signal_connect(
  toggled => sub {
   if ( $babutton->get_active ) {
    $bframe->set_sensitive(FALSE);
   }
   else {
    $bframe->set_sensitive(TRUE);
   }
  }
 );

 # Define margins here to reference them below
 my $bmframe = $self->add_widget( $vbox2, $options, 'border-margin' );

 foreach ( keys %{ $options->{'border-align'}{options} } ) {
  my $button = $options->{'border-align'}{options}{$_}{widget};

  # Ghost margin if nothing selected
  $button->signal_connect(
   toggled => sub {
    if ( count_active_children($bframe) == 0 ) {
     $bmframe->set_sensitive(FALSE);
    }
    else {
     $bmframe->set_sensitive(TRUE);
    }
   }
  );
 }
 if ( count_active_children($bframe) == 0 ) {
  $bmframe->set_sensitive(FALSE);
 }
 else {
  $bmframe->set_sensitive(TRUE);
 }

 # Notebook page 3
 my $vbox3 = Gtk2::VBox->new;
 $notebook->append_page( $vbox3, $main::d->get('Filters') );

 my $spinbuttonwt = $self->add_widget( $vbox3, $options, 'white-threshold' );
 my $spinbuttonbt = $self->add_widget( $vbox3, $options, 'black-threshold' );
 my $msbutton     = $self->add_widget( $vbox3, $options, 'no-mask-scan' );
 my $bfbutton     = $self->add_widget( $vbox3, $options, 'no-blackfilter' );
 my $gfbutton     = $self->add_widget( $vbox3, $options, 'no-grayfilter' );
 my $nfbutton     = $self->add_widget( $vbox3, $options, 'no-noisefilter' );
 my $blbutton     = $self->add_widget( $vbox3, $options, 'no-blurfilter' );
 return;
}

sub count_active_children {
 my ($frame) = @_;
 my $n = 0;
 for ( $frame->get_child->get_children ) {
  $n++ if ( $_->get_active );
 }
 return $n;
}

# Add widget to unpaper dialog

sub add_widget {
 my ( $self, $vbox, $hashref, $option ) = @_;
 my $default  = $self->{default};
 my $tooltips = Gtk2::Tooltips->new;
 $tooltips->enable;

 my $widget;
 $default->{$option} = $hashref->{$option}{default}
   if ( defined( $hashref->{$option}{default} )
  and not defined( $default->{$option} ) );

 if ( $hashref->{$option}{type} eq 'ComboBox' ) {
  my $hbox = Gtk2::HBox->new;
  $vbox->pack_start( $hbox, TRUE, TRUE, 0 );
  my $label = Gtk2::Label->new( $hashref->{$option}{string} );
  $hbox->pack_start( $label, FALSE, FALSE, 0 );
  $widget = Gtk2::ComboBox->new_text;
  $hbox->pack_end( $widget, FALSE, FALSE, 0 );

  # Add text and tooltips
  my @tooltip;
  my $i = -1;
  my $o = 0;
  foreach ( keys %{ $hashref->{$option}{options} } ) {
   $widget->append_text( $hashref->{$option}{options}{$_}{string} );
   push @tooltip, $hashref->{$option}{options}{$_}{tooltip};
   $hashref->{$option}{options}{$_}{index} = ++$i;
   $o = $i if ( $_ eq $default->{$option} );
  }
  $widget->signal_connect(
   changed => sub {
    $tooltips->set_tip( $widget, $tooltip[ $widget->get_active ] )
      if ( defined $tooltip[ $widget->get_active ] );
   }
  );

  # Set defaults
  $widget->set_active($o);
  $tooltips->set_tip( $widget, $tooltip[0] );
 }

 elsif ( $hashref->{$option}{type} eq 'CheckButton' ) {
  $widget = Gtk2::CheckButton->new( $hashref->{$option}{string} );
  $tooltips->set_tip( $widget, $hashref->{$option}{tooltip} );
  $vbox->pack_start( $widget, TRUE, TRUE, 0 );
  $widget->set_active( $default->{$option} ) if defined( $default->{$option} );
 }

 elsif ( $hashref->{$option}{type} eq 'CheckButtonGroup' ) {
  $widget = Gtk2::Frame->new( $hashref->{$option}{string} );
  $vbox->pack_start( $widget, TRUE, TRUE, 0 );
  my $vboxf = Gtk2::VBox->new;
  $vboxf->set_border_width($border_width);
  $widget->add($vboxf);
  $tooltips->set_tip( $widget, $hashref->{$option}{tooltip} );
  my %default;
  if ( defined $default->{$option} ) {

   foreach ( split /,/, $default->{$option} ) {
    $default{$_} = TRUE;
   }
  }
  foreach ( keys %{ $hashref->{$option}{options} } ) {
   my $button = $self->add_widget( $vboxf, $hashref->{$option}{options}, $_ );
   $button->set_active(TRUE) if ( defined $default{$_} );
  }
 }

 elsif ( $hashref->{$option}{type} eq 'SpinButton' ) {
  my $hbox = Gtk2::HBox->new;
  $vbox->pack_start( $hbox, TRUE, TRUE, 0 );
  my $label = Gtk2::Label->new( $hashref->{$option}{string} );
  $hbox->pack_start( $label, FALSE, FALSE, 0 );
  $widget = Gtk2::SpinButton->new_with_range(
   $hashref->{$option}{min},
   $hashref->{$option}{max},
   $hashref->{$option}{step}
  );
  $hbox->pack_end( $widget, FALSE, FALSE, 0 );
  $tooltips->set_tip( $widget, $hashref->{$option}{tooltip} );
  $widget->set_value( $default->{$option} ) if ( defined $default->{$option} );
 }

 elsif ( $hashref->{$option}{type} eq 'SpinButtonGroup' ) {
  $widget = Gtk2::Frame->new( $hashref->{$option}{string} );
  $vbox->pack_start( $widget, TRUE, TRUE, 0 );
  my $vboxf = Gtk2::VBox->new;
  $vboxf->set_border_width($border_width);
  $widget->add($vboxf);
  my @default;
  @default = split /,/, $default->{$option} if ( defined $default->{$option} );
  foreach (
   sort {
    $hashref->{$option}{options}{$a}{order} <=> $hashref->{$option}{options}{$b}
      {order}
   } keys %{ $hashref->{$option}{options} }
    )
  {
   my $button = $self->add_widget( $vboxf, $hashref->{$option}{options}, $_ );
   $button->set_value( shift @default ) if (@default);
  }
 }

 $hashref->{$option}{widget} = $widget;
 return $widget;
}

sub get_options {
 my ($self) = @_;
 my $hashref = $self->{options};
 my $default;

 foreach my $option ( keys %{$hashref} ) {
  if ( $hashref->{$option}{type} eq 'ComboBox' ) {
   my $i = $hashref->{$option}{widget}->get_active;
   for ( keys %{ $hashref->{$option}{options} } ) {
    $default->{$option} = $_
      if ( $hashref->{$option}{options}{$_}{index} == $i );
   }
  }
  elsif ( $hashref->{$option}{type} eq 'CheckButton' ) {
   $default->{$option} = $hashref->{$option}{widget}->get_active ? TRUE : FALSE;
  }
  elsif ( $hashref->{$option}{type} eq 'SpinButton' ) {
   $default->{$option} = $hashref->{$option}{widget}->get_value;
  }
  elsif ( $hashref->{$option}{type} eq 'CheckButtonGroup' ) {
   my @items;
   foreach ( keys %{ $hashref->{$option}{options} } ) {
    push @items, $_ if ( $hashref->{$option}{options}{$_}{widget}->get_active );
   }
   $default->{$option} = join ',', @items if (@items);
  }
  elsif ( $hashref->{$option}{type} eq 'SpinButtonGroup' ) {
   my @items;
   foreach ( keys %{ $hashref->{$option}{options} } ) {
    push @items, $hashref->{$option}{options}{$_}{widget}->get_value;
   }
   $default->{$option} = join ',', @items if (@items);
  }
 }
 return $default;
}

# was options2unpaper

sub get_cmdline {
 my ($self)  = @_;
 my $hashref = $self->{options};
 my $default = $self->get_options;

 my @items;
 foreach my $option ( keys %{$hashref} ) {
  if ( $hashref->{$option}{type} eq 'CheckButton' ) {
   push @items, "--$option"
     if ( defined $default->{$option} and $default->{$option} );
  }
  else {
   push @items, "--$option $default->{$option}"
     if ( defined $default->{$option} );
  }
 }
 return join ' ', @items;
}

1;

__END__
