package Gscan2pdf::Dialog::Scan::CLI;

# TODO: put the test code in to use the --help output from other people's scanners

use warnings;
use strict;
use Gscan2pdf::Dialog::Scan;
use Glib qw(TRUE FALSE);   # To get TRUE and FALSE
use Sane 0.05;             # To get SANE_NAME_PAGE_WIDTH & SANE_NAME_PAGE_HEIGHT
use Gscan2pdf::Frontend::CLI;
use Locale::gettext 1.05;    # For translations
use feature "switch";

# logger duplicated from Gscan2pdf::Dialog::Scan
# to ensure that SET_PROPERTIES gets called in both places
use Glib::Object::Subclass Gscan2pdf::Dialog::Scan::, properties => [
 Glib::ParamSpec->string(
  'frontend',                       # name
  'Frontend',                       # nick
  '(scanimage|scanadf)(-perl)?',    # blurb
  '',                               # default
  [qw/readable writable/]           # flags
 ),
 Glib::ParamSpec->scalar(
  'logger',                              # name
  'Logger',                              # nick
  'Log::Log4perl::get_logger object',    # blurb
  [qw/readable writable/]                # flags
 ),
 Glib::ParamSpec->string(
  'prefix',                              # name
  'Prefix',                              # nick
  'Prefix for command line calls',       # blurb
  '',                                    # default
  [qw/readable writable/]                # flags
 ),
 Glib::ParamSpec->scalar(
  'reload-triggers',                                               # name
  'Reload triggers',                                               # nick
  'Hash of option names that cause the options to be reloaded',    # blurb
  [qw/readable writable/]                                          # flags
 ),
];

my $SANE_NAME_PAGE_HEIGHT = SANE_NAME_PAGE_HEIGHT;
my $SANE_NAME_PAGE_WIDTH  = SANE_NAME_PAGE_WIDTH;
my ( $d, $d_sane, $logger, $tooltips );

# Normally, we would initialise the widget in INIT_INSTANCE and use the
# default constructor new(). However, we have to override the default contructor
# in order to be able to access any properties assigned in ->new(), which are
# not available in INIT_INSTANCE. Therefore, we use the default INIT_INSTANCE,
# and override new(). If we ever need to subclass Gscan2pdf::Scanner::Dialog,
# then we would need to put the bulk of this code back into INIT_INSTANCE,
# and leave just that which assigns the required properties.

sub new {
 my ( $class, @arguments ) = @_;
 my $self = Glib::Object::new( $class, @arguments );

 my $vbox = $self->get('vbox');
 $tooltips = Gtk2::Tooltips->new;
 $tooltips->enable;

 $d      = Locale::gettext->domain(Glib::get_application_name);
 $d_sane = Locale::gettext->domain('sane-backends');

 # device list
 $self->{hboxd} = Gtk2::HBox->new;
 my $labeld = Gtk2::Label->new( $d->get('Device') );
 $self->{hboxd}->pack_start( $labeld, FALSE, FALSE, 0 );
 $self->{combobd} = Gtk2::ComboBox->new_text;
 $self->{combobd}->append_text( $d->get('Rescan for devices') );

 $self->{combobd_changed_signal} = $self->{combobd}->signal_connect(
  changed => sub {
   my $index       = $self->{combobd}->get_active;
   my $device_list = $self->get('device-list');
   if ( $index > $#$device_list ) {
    $self->{combobd}->hide;
    $labeld->hide;
    $self->set( 'device', undef );    # to make sure that the device is reloaded
    $self->get_devices;
   }
   elsif ( $index > -1 ) {
    $self->scan_options( $device_list->[$index] );
   }
  }
 );
 $self->signal_connect(
  'changed-device' => sub {
   my ( $widget, $device ) = @_;
   my $device_list = $self->get('device-list');
   for (@$device_list) {
    if ( $_->{name} eq $device ) {
     Gscan2pdf::Dialog::Scan::set_combobox_by_text( $self->{combobd},
      $_->{label} );
     return;
    }
   }
  }
 );
 $tooltips->set_tip( $self->{combobd},
  $d->get('Sets the device to be used for the scan') );
 $self->{hboxd}->pack_end( $self->{combobd}, FALSE, FALSE, 0 );
 $vbox->pack_start( $self->{hboxd}, FALSE, FALSE, 0 );

 # Notebook to collate options
 $self->{notebook} = Gtk2::Notebook->new;
 $vbox->pack_start( $self->{notebook}, TRUE, TRUE, 0 );

 # Notebook page 1
 my $vbox1 = Gtk2::VBox->new;
 $self->{vbox} = $vbox1;
 $self->{notebook}->append_page( $vbox1, $d->get('Page Options') );

 # Frame for # pages
 my $framen = Gtk2::Frame->new( $d->get('# Pages') );
 $vbox1->pack_start( $framen, FALSE, FALSE, 0 );
 my $vboxn        = Gtk2::VBox->new;
 my $border_width = $self->get('border_width');
 $vboxn->set_border_width($border_width);
 $framen->add($vboxn);

 #the first radio button has to set the group,
 #which is undef for the first button
 # All button
 my $bscanall = Gtk2::RadioButton->new( undef, $d->get('All') );
 $tooltips->set_tip( $bscanall, $d->get('Scan all pages') );
 $vboxn->pack_start( $bscanall, TRUE, TRUE, 0 );
 $bscanall->signal_connect(
  clicked => sub {
   $self->set( 'num-pages', 0 ) if ( $bscanall->get_active );
  }
 );

 # Entry button
 my $hboxn = Gtk2::HBox->new;
 $vboxn->pack_start( $hboxn, TRUE, TRUE, 0 );
 my $bscannum = Gtk2::RadioButton->new( $bscanall->get_group, "#:" );
 $tooltips->set_tip( $bscannum, $d->get('Set number of pages to scan') );
 $hboxn->pack_start( $bscannum, FALSE, FALSE, 0 );

 # Number of pages
 my $spin_buttonn = Gtk2::SpinButton->new_with_range( 1, 999, 1 );
 $tooltips->set_tip( $spin_buttonn, $d->get('Set number of pages to scan') );
 $hboxn->pack_end( $spin_buttonn, FALSE, FALSE, 0 );
 $bscannum->signal_connect(
  clicked => sub {
   $self->set( 'num-pages', $spin_buttonn->get_value )
     if ( $bscannum->get_active );
  }
 );
 $self->signal_connect(
  'changed-num-pages' => sub {
   my ( $widget, $value ) = @_;
   if ( $value == 0 ) {
    $bscanall->set_active(TRUE);
   }
   else {
    $spin_buttonn->set_value($value);
   }
  }
 );

 # Actively set a radio button to synchronise GUI and properties
 if ( $self->get('num-pages') > 0 ) {
  $bscannum->set_active(TRUE);
 }
 else {
  $bscanall->set_active(TRUE);
 }

 # Toggle to switch between basic and extended modes
 my $checkx = Gtk2::CheckButton->new( $d->get('Extended page numbering') );
 $vbox1->pack_start( $checkx, FALSE, FALSE, 0 );

 # Frame for extended mode
 $self->{framex} = Gtk2::Frame->new( $d->get('Page number') );
 $vbox1->pack_start( $self->{framex}, FALSE, FALSE, 0 );
 my $vboxx = Gtk2::VBox->new;
 $vboxx->set_border_width($border_width);
 $self->{framex}->add($vboxx);

 # SpinButton for starting page number
 my $hboxxs = Gtk2::HBox->new;
 $vboxx->pack_start( $hboxxs, FALSE, FALSE, 0 );
 my $labelxs = Gtk2::Label->new( $d->get('Start') );
 $hboxxs->pack_start( $labelxs, FALSE, FALSE, 0 );
 my $spin_buttons = Gtk2::SpinButton->new_with_range( 1, 99999, 1 );
 $hboxxs->pack_end( $spin_buttons, FALSE, FALSE, 0 );
 $spin_buttons->signal_connect(
  'value-changed' => sub {
   $self->set( 'page-number-start', $spin_buttons->get_value );
  }
 );
 $self->signal_connect(
  'changed-page-number-start' => sub {
   my ( $widget, $value ) = @_;
   $spin_buttons->set_value($value);
  }
 );

 # SpinButton for page number increment
 my $hboxi = Gtk2::HBox->new;
 $vboxx->pack_start( $hboxi, FALSE, FALSE, 0 );
 my $labelxi = Gtk2::Label->new( $d->get('Increment') );
 $hboxi->pack_start( $labelxi, FALSE, FALSE, 0 );
 my $spin_buttoni = Gtk2::SpinButton->new_with_range( -99, 99, 1 );
 $spin_buttoni->set_value( $self->get('page-number-increment') );
 $hboxi->pack_end( $spin_buttoni, FALSE, FALSE, 0 );
 $spin_buttoni->signal_connect(
  'value-changed' => sub {
   my $value = $spin_buttoni->get_value;
   $value = -$self->get('page-number-increment') if ( $value == 0 );
   $spin_buttoni->set_value($value);
   $self->set( 'page-number-increment', $value );
  }
 );
 $self->signal_connect(
  'changed-page-number-increment' => sub {
   my ( $widget, $value ) = @_;
   $spin_buttoni->set_value($value);
  }
 );

 # Setting this here to fire callback running update_start
 $spin_buttons->set_value( $self->get('page-number-start') );

 # Callback on changing number of pages
 $spin_buttonn->signal_connect(
  'value-changed' => sub {
   $self->set( 'num-pages', $spin_buttonn->get_value );
   $bscannum->set_active(TRUE);    # Set the radiobutton active
  }
 );

 # Frame for standard mode
 my $frames = Gtk2::Frame->new( $d->get('Source document') );
 $vbox1->pack_start( $frames, FALSE, FALSE, 0 );
 my $vboxs = Gtk2::VBox->new;
 $vboxs->set_border_width($border_width);
 $frames->add($vboxs);

 # Single sided button
 my $buttons = Gtk2::RadioButton->new( undef, $d->get('Single sided') );
 $tooltips->set_tip( $buttons, $d->get('Source document is single-sided') );
 $vboxs->pack_start( $buttons, TRUE, TRUE, 0 );
 $buttons->signal_connect(
  clicked => sub {
   $spin_buttoni->set_value(1);
  }
 );

 # Double sided button
 my $buttond =
   Gtk2::RadioButton->new( $buttons->get_group, $d->get('Double sided') );
 $tooltips->set_tip( $buttond, $d->get('Source document is double-sided') );
 $vboxs->pack_start( $buttond, FALSE, FALSE, 0 );

 # Facing/reverse page button
 my $hboxs = Gtk2::HBox->new;
 $vboxs->pack_start( $hboxs, TRUE, TRUE, 0 );
 my $labels = Gtk2::Label->new( $d->get('Side to scan') );
 $hboxs->pack_start( $labels, FALSE, FALSE, 0 );

 my $combobs = Gtk2::ComboBox->new_text;
 for ( ( $d->get('Facing'), $d->get('Reverse') ) ) {
  $combobs->append_text($_);
 }
 $combobs->signal_connect(
  changed => sub {
   $buttond->set_active(TRUE);    # Set the radiobutton active
   $self->set( 'side-to-scan',
    $combobs->get_active == 0 ? 'facing' : 'reverse' );
  }
 );
 $self->signal_connect(
  'changed-side-to-scan' => sub {
   my ( $widget, $value ) = @_;
   $self->set( 'page-number-increment', $value eq 'facing' ? 2 : -2 );
  }
 );
 $tooltips->set_tip( $combobs,
  $d->get('Sets which side of a double-sided document is scanned') );
 $combobs->set_active(0);

 # Have to do this here because setting the facing combobox switches it
 $buttons->set_active(TRUE);
 $hboxs->pack_end( $combobs, FALSE, FALSE, 0 );

 # Have to put the double-sided callback here to reference page side
 $buttond->signal_connect(
  clicked => sub {
   $spin_buttoni->set_value( $combobs->get_active == 0 ? 2 : -2 );
  }
 );

# Have to put the extended pagenumber checkbox here to reference simple controls
 $checkx->signal_connect(
  toggled => \&_extended_pagenumber_checkbox_callback,
  [ $self, $frames, $spin_buttoni, $buttons, $buttond, $combobs ]
 );

 # Scan profiles
 my $framesp = Gtk2::Frame->new( $d->get('Scan profiles') );
 $vbox1->pack_start( $framesp, FALSE, FALSE, 0 );
 my $vboxsp = Gtk2::VBox->new;
 $vboxsp->set_border_width($border_width);
 $framesp->add($vboxsp);
 $self->{combobsp} = Gtk2::ComboBox->new_text;
 $self->{combobsp}->signal_connect(
  changed => sub {
   my $profile = $self->{combobsp}->get_active_text;
   $self->set( 'profile', $profile ) if ( defined $profile );
  }
 );
 $vboxsp->pack_start( $self->{combobsp}, FALSE, FALSE, 0 );
 my $hboxsp = Gtk2::HBox->new;
 $vboxsp->pack_end( $hboxsp, FALSE, FALSE, 0 );

 # Save button
 my $vbutton = Gtk2::Button->new_from_stock('gtk-save');
 $vbutton->signal_connect(
  clicked => sub {
   my $dialog = Gtk2::Dialog->new(
    $d->get('Name of scan profile'), $self,
    'destroy-with-parent',
    'gtk-save'   => 'ok',
    'gtk-cancel' => 'cancel'
   );
   my $hbox  = Gtk2::HBox->new;
   my $label = Gtk2::Label->new( $d->get('Name of scan profile') );
   $hbox->pack_start( $label, FALSE, FALSE, 0 );
   my $entry = Gtk2::Entry->new;
   $entry->set_activates_default(TRUE);
   $hbox->pack_end( $entry, TRUE, TRUE, 0 );
   $dialog->vbox->add($hbox);
   $dialog->set_default_response('ok');
   $dialog->show_all;

   if ( $dialog->run eq 'ok' and $entry->get_text !~ /^\s*$/x ) {
    my $profile = $entry->get_text;
    $self->add_profile( $profile, $self->get('current-scan-options') );
    $self->{combobsp}->set_active( num_rows_combobox( $self->{combobsp} ) );
   }
   $dialog->destroy;
  }
 );
 $hboxsp->pack_start( $vbutton, TRUE, TRUE, 0 );

 # Delete button
 my $dbutton = Gtk2::Button->new_from_stock('gtk-delete');
 $dbutton->signal_connect(
  clicked => sub {
   $self->remove_profile( $self->{combobsp}->get_active_text );
  }
 );
 $hboxsp->pack_start( $dbutton, FALSE, FALSE, 0 );

 # HBox for buttons
 my $hboxb = Gtk2::HBox->new;
 $vbox->pack_end( $hboxb, FALSE, FALSE, 0 );

 # Scan button
 $self->{sbutton} = Gtk2::Button->new( $d->get('Scan') );
 $hboxb->pack_start( $self->{sbutton}, TRUE, TRUE, 0 );
 $self->{sbutton}->signal_connect( clicked => sub { $self->scan; } );

 # Cancel button
 my $cbutton = Gtk2::Button->new_from_stock('gtk-close');
 $hboxb->pack_end( $cbutton, FALSE, FALSE, 0 );
 $cbutton->signal_connect( clicked => sub { $self->hide; } );

 # FIXME: this has to be done somewhere else
 # Has to be done in idle cycles to wait for the options to finish building
 Glib::Idle->add( sub { $self->{sbutton}->grab_focus; } );
 return $self;
}

sub SET_PROPERTY {
 my ( $self, $pspec, $newval ) = @_;
 my $name   = $pspec->get_name;
 my $oldval = $self->get($name);
 $self->{$name} = $newval;
 if (( defined($newval) and defined($oldval) and $newval ne $oldval )
  or ( defined($newval) xor defined($oldval) ) )
 {
  if ( $name eq 'logger' ) { $logger = $self->get('logger') }
 }
 $self->SUPER::SET_PROPERTY( $pspec, $newval );
 return;
}

# Run scanimage --formatted-device-list

sub get_devices {
 my ($self) = @_;

 my $pbar;
 my $hboxd = $self->{hboxd};
 Gscan2pdf::Frontend::CLI->get_devices(
  prefix           => $self->get('prefix'),
  started_callback => sub {

   # Set up ProgressBar
   $pbar = Gtk2::ProgressBar->new;
   $pbar->set_pulse_step(.1);
   $pbar->set_text( $d->get('Fetching list of devices') );
   $hboxd->pack_start( $pbar, TRUE, TRUE, 0 );
   $hboxd->hide_all;
   $hboxd->show;
   $pbar->show;
  },
  running_callback  => sub { $pbar->pulse },
  finished_callback => sub {
   my ($device_list) = @_;
   $pbar->destroy;
   my @device_list = @{$device_list};
   use Data::Dumper;
   $logger->info( "scanimage --formatted-device-list: ",
    Dumper( \@device_list ) );
   if ( @device_list == 0 ) {
    $self->signal_emit( 'process-error', $d->get('No devices found') );
    $self->destroy;
    undef $self;
    return FALSE;
   }
   $self->set( 'device-list', \@device_list );
   $hboxd->show_all;
  }
 );
 return;
}

# Scan device-dependent scan options

sub scan_options {
 my ($self) = @_;

 # Remove any existing pages
 while ( $self->{notebook}->get_n_pages > 1 ) {
  $self->{notebook}->remove_page(-1);
 }

 # Ghost the scan button whilst options being updated
 $self->{sbutton}->set_sensitive(FALSE) if ( defined $self->{sbutton} );

 my $pbar;
 my $hboxd = $self->{hboxd};
 Gscan2pdf::Frontend::CLI->find_scan_options(
  prefix           => $self->get('prefix'),
  frontend         => $self->get('frontend'),
  device           => $self->get('device'),
  options          => $self->{current_scan_options},
  started_callback => sub {

   # Set up ProgressBar
   $pbar = Gtk2::ProgressBar->new;
   $pbar->set_pulse_step(.1);
   $pbar->set_text( $d->get('Updating options') );
   $hboxd->pack_start( $pbar, TRUE, TRUE, 0 );
   $hboxd->hide_all;
   $hboxd->show;
   $pbar->show;
  },
  running_callback => sub {
   $pbar->pulse;
  },
  finished_callback => sub {
   my ($options) = @_;
   $pbar->destroy;
   $logger->info($options);
   $self->_initialise_options($options);

   $self->signal_emit( 'finished-process', 'find_scan_options' );

   # This fires the reloaded-scan-options signal,
   # so don't set this until we have finished
   $self->set( 'available-scan-options', $options );
  },
  error_callback => sub {
   my ($message) = @_;
   $pbar->destroy;
   $self->signal_emit( 'process-error', $message );
   $logger->warn($message);
  },
 );
 return;
}

sub _extended_pagenumber_checkbox_callback {
 my ( $widget, $data ) = @_;
 my ( $dialog, $frames, $spin_buttoni, $buttons, $buttond, $combobs ) = @$data;
 if ( $widget->get_active ) {
  $frames->hide_all;
  $dialog->{framex}->show_all;
 }
 else {
  if ( $spin_buttoni->get_value == 1 ) {
   $buttons->set_active(TRUE);
  }
  elsif ( $spin_buttoni->get_value > 0 ) {
   $buttond->set_active(TRUE);
   $combobs->set_active(0);
  }
  else {
   $buttond->set_active(TRUE);
   $combobs->set_active(1);
  }
  $frames->show_all;
  $dialog->{framex}->hide_all;
 }
 return;
}

sub _initialise_options {    ## no critic (ProhibitExcessComplexity)
 my ( $self, $options ) = @_;
 $logger->debug( "scanimage --help returned: ", Dumper($options) );

 my $num_dev_options = $options->num_options;

 # We have hereby removed the active profile and paper,
 # so update the properties without triggering the signals
 $self->{profile}       = undef;
 $self->{paper_formats} = undef;
 $self->{paper}         = undef;

 # Default tab
 my $vbox = Gtk2::VBox->new;
 $self->{notebook}->append_page( $vbox, $d->get('Scan Options') );

 delete $self->{combobp};    # So we don't carry over from one device to another
 for ( my $i = 1 ; $i < $num_dev_options ; ++$i ) {
  my $opt = $options->by_index($i);

  # Notebook page for group
  if ( $opt->{type} == SANE_TYPE_GROUP ) {
   $vbox = Gtk2::VBox->new;
   my $i =
     $self->{notebook}->append_page( $vbox, $d_sane->get( $opt->{title} ) );
   $opt->{widget} = $vbox;
   next;
  }

  next unless ( $opt->{cap} & SANE_CAP_SOFT_DETECT );

  # Widget
  my ( $widget, $val );
  $val = $opt->{val};

  # Define HBox for paper size here
  # so that it can be put before first geometry option
  if ( _geometry_option($opt) and not defined( $self->{hboxp} ) ) {
   $self->{hboxp} = Gtk2::HBox->new;
   $vbox->pack_start( $self->{hboxp}, FALSE, FALSE, 0 );
  }

  # HBox for option
  my $hbox = Gtk2::HBox->new;
  $vbox->pack_start( $hbox, FALSE, TRUE, 0 );
  $hbox->set_sensitive(FALSE)
    if ( $opt->{cap} & SANE_CAP_INACTIVE
   or not $opt->{cap} & SANE_CAP_SOFT_SELECT );

  if ( $opt->{max_values} < 2 ) {

   # Label
   if ( $opt->{type} != SANE_TYPE_BUTTON ) {
    my $label = Gtk2::Label->new( $d_sane->get( $opt->{title} ) );
    $hbox->pack_start( $label, FALSE, FALSE, 0 );
   }

   # CheckButton
   if ( $opt->{type} == SANE_TYPE_BOOL )
   {    ## no critic (ProhibitCascadingIfElse)
    $widget = Gtk2::CheckButton->new;
    $widget->set_active(TRUE) if ($val);
    $widget->{signal} = $widget->signal_connect(
     toggled => sub {
      my $value = $widget->get_active;
      $self->set_option( $opt, $value );
     }
    );
   }

   # Button
   elsif ( $opt->{type} == SANE_TYPE_BUTTON ) {
    $widget = Gtk2::Button->new( $d_sane->get( $opt->{title} ) );
    $widget->{signal} = $widget->signal_connect(
     clicked => sub {
      $self->set_option( $opt, $val );
     }
    );
   }

   # SpinButton
   elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_RANGE ) {
    my $step = 1;
    $step = $opt->{constraint}{quant} if ( $opt->{constraint}{quant} );
    $widget = Gtk2::SpinButton->new_with_range( $opt->{constraint}{min},
     $opt->{constraint}{max}, $step );

    # Set the default
    $widget->set_value($val)
      if ( defined $val and not $opt->{cap} & SANE_CAP_INACTIVE );
    $widget->{signal} = $widget->signal_connect(
     'value-changed' => sub {
      my $value = $widget->get_value;
      $self->set_option( $opt, $value );
     }
    );
   }

   # ComboBox
   elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_STRING_LIST
    or $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST )
   {
    $widget = Gtk2::ComboBox->new_text;
    my $index = 0;
    for ( my $i = 0 ; $i < @{ $opt->{constraint} } ; ++$i ) {
     $widget->append_text( $d_sane->get( $opt->{constraint}[$i] ) );
     $index = $i if ( defined $val and $opt->{constraint}[$i] eq $val );
    }

    # Set the default
    $widget->set_active($index) if ( defined $index );
    $widget->{signal} = $widget->signal_connect(
     changed => sub {
      my $i = $widget->get_active;
      $self->set_option( $opt, $opt->{constraint}[$i] );
     }
    );
   }

   # Entry
   elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_NONE ) {
    $widget = Gtk2::Entry->new;

    # Set the default
    $widget->set_text($val)
      if ( defined $val and not $opt->{cap} & SANE_CAP_INACTIVE );
    $widget->{signal} = $widget->signal_connect(
     activate => sub {
      my $value = $widget->get_text;
      $self->set_option( $opt, $value );
     }
    );
   }
  }
  else {    # $opt->{max_values} > 1
   $widget = Gtk2::Button->new( $d_sane->get( $opt->{title} ) );
   $widget->{signal} = $widget->signal_connect(
    clicked => \&_multiple_values_button_callback,
    [ $self, $opt ]
   );
  }

  $self->_pack_widget( $widget, [ $options, $opt, $hbox ] );
 }

 # Set defaults
 my $sane_device = Gscan2pdf::Frontend::CLI->device;

 # Callback for option visibility
 $self->signal_connect(
  'changed-option-visibility' => sub {
   my ( $widget, $visible_options ) = @_;
   $self->_update_option_visibility( $options, $visible_options );
  }
 );
 $self->_update_option_visibility( $options,
  $self->get('visible-scan-options') );

 # Give the GUI a chance to catch up before resizing.
 Glib::Idle->add( sub { $self->resize( 100, 100 ); } );

 $self->{sbutton}->set_sensitive(TRUE);
 $self->{sbutton}->grab_focus;
 return;
}

sub _update_option_visibility {
 my ( $self, $options, $visible_options ) = @_;

 # Show all notebook tabs
 for ( my $i = 1 ; $i < $self->{notebook}->get_n_pages ; $i++ ) {
  $self->{notebook}->get_nth_page($i)->show_all;
 }

 my $num_dev_options = $options->num_options;
 for ( my $i = 1 ; $i < $num_dev_options ; ++$i ) {
  my $opt = $options->{array}[$i];
  my $show;
  if ( defined $visible_options->{ $opt->{name} } ) {
   $show = $visible_options->{ $opt->{name} };
  }
  elsif ( defined $visible_options->{ $opt->{title} } ) {
   $show = $visible_options->{ $opt->{title} };
  }
  my $container =
    $opt->{type} == SANE_TYPE_GROUP ? $opt->{widget} : $opt->{widget}->parent;
  my $geometry = _geometry_option($opt);
  if ($show) {
   $container->show_all;

   # Find associated group
   unless ( $opt->{type} == SANE_TYPE_GROUP ) {
    my $j = $i;
    while ( --$j > 0 and $options->{array}[$j]{type} != SANE_TYPE_GROUP ) {
    }
    if ( $j > 0 and not $options->{array}[$j]{widget}->visible ) {
     my $group = $options->{array}[$j]{widget};
     unless ( $group->visible ) {
      $group->remove($container);
      my $move_paper =
        (    $geometry
         and defined( $self->{hboxp} )
         and $self->{hboxp}->parent eq $group );
      $group->remove( $self->{hboxp} ) if ($move_paper);

      # Find visible group
      while (
       --$j > 0
       and ( $options->{array}[$j]{type} != SANE_TYPE_GROUP
        or ( not $options->{array}[$j]{widget}->visible ) )
        )
      {
      }
      if ( $j > 0 ) {
       $group = $options->{array}[$j]{widget};
      }
      else {
       $group = $self->{notebook}->get_nth_page(1);
      }
      $group->pack_start( $self->{hboxp}, FALSE, FALSE, 0 ) if ($move_paper);
      $group->pack_start( $container, FALSE, FALSE, 0 );
     }
    }
   }
  }
  else {
   $container->hide_all;
  }
 }
 if ( defined $visible_options->{'Paper size'} ) {
  $self->{hboxp}->show_all;
 }
 else {
  $self->{hboxp}->hide_all;
 }
 return;
}

# Return true if we have a valid geometry option

sub _geometry_option {
 my ($opt) = @_;
 return (
        ( $opt->{type} == SANE_TYPE_FIXED or $opt->{type} == SANE_TYPE_INT )
    and ( $opt->{unit} == SANE_UNIT_MM or $opt->{unit} == SANE_UNIT_PIXEL )
    and ( $opt->{name} =~
   /^(?:l|t|x|y|$SANE_NAME_PAGE_HEIGHT|$SANE_NAME_PAGE_WIDTH)$/x )
 );
}

sub _create_paper_widget {
 my ( $self, $options ) = @_;

 # Only define the paper size once the rest of the geometry widgets
 # have been created
 if (
      defined( $options->{box}{x} )
  and defined( $options->{box}{y} )
  and defined( $options->{box}{l} )
  and defined( $options->{box}{t} )
  and ( not defined $options->by_name(SANE_NAME_PAGE_HEIGHT)
   or defined( $options->{box}{$SANE_NAME_PAGE_HEIGHT} ) )
  and ( not defined $options->by_name(SANE_NAME_PAGE_WIDTH)
   or defined( $options->{box}{$SANE_NAME_PAGE_WIDTH} ) )
  and not defined( $self->{combobp} )
   )
 {
  # Paper list
  my $label = Gtk2::Label->new( $d->get('Paper size') );
  $self->{hboxp}->pack_start( $label, FALSE, FALSE, 0 );

  $self->{combobp} = Gtk2::ComboBox->new_text;
  $self->{combobp}->append_text( $d->get('Manual') );
  $self->{combobp}->append_text( $d->get('Edit') );
  $tooltips->set_tip( $self->{combobp},
   $d->get('Selects or edits the paper size') );
  $self->{hboxp}->pack_end( $self->{combobp}, FALSE, FALSE, 0 );
  $self->{combobp}->set_active(0);
  $self->{combobp}->signal_connect(
   changed => sub {

    if ( $self->{combobp}->get_active_text eq $d->get('Edit') ) {
     $self->edit_paper;
    }
    elsif ( $self->{combobp}->get_active_text eq $d->get('Manual') ) {
     for ( ( 'l', 't', 'x', 'y', SANE_NAME_PAGE_HEIGHT, SANE_NAME_PAGE_WIDTH ) )
     {
      $options->{box}{$_}->show_all if ( defined $options->{box}{$_} );
     }
    }
    else {
     my $paper   = $self->{combobp}->get_active_text;
     my $formats = $self->get('paper-formats');
     if ( defined( $options->by_name(SANE_NAME_PAGE_HEIGHT) )
      and defined( $options->by_name(SANE_NAME_PAGE_WIDTH) ) )
     {
      $options->by_name(SANE_NAME_PAGE_HEIGHT)->{widget}
        ->set_value( $formats->{$paper}{y} + $formats->{$paper}{t} );
      $options->by_name(SANE_NAME_PAGE_WIDTH)->{widget}
        ->set_value( $formats->{$paper}{x} + $formats->{$paper}{l} );
     }

     $options->by_name('l')->{widget}->set_value( $formats->{$paper}{l} );
     $options->by_name('t')->{widget}->set_value( $formats->{$paper}{t} );
     $options->by_name('x')->{widget}->set_value( $formats->{$paper}{x} );
     $options->by_name('y')->{widget}->set_value( $formats->{$paper}{y} );
     Glib::Idle->add(
      sub {
       for (
        ( 'l', 't', 'x', 'y', SANE_NAME_PAGE_HEIGHT, SANE_NAME_PAGE_WIDTH ) )
       {
        $options->{box}{$_}->hide_all if ( defined $options->{box}{$_} );
       }
      }
     );

     # Do this last, as it fires the changed-paper signal
     $self->set( 'paper', $paper );
    }
   }
  );
 }
 return;
}

sub _multiple_values_button_callback {
 my ( $widget, $data ) = @_;
 my ( $dialog, $opt )  = @$data;
 if ($opt->{type} == SANE_TYPE_FIXED
  or $opt->{type} == SANE_TYPE_INT )
 {
  if ( $opt->{constraint_type} == SANE_CONSTRAINT_NONE ) {
   main::show_message_dialog(
    $dialog, 'info', 'close',
    $d->get(
'Multiple unconstrained values are not currently supported. Please file a bug.'
    )
   );
  }
  else {
   $dialog->set_options($opt);
  }
 }
 else {
  main::show_message_dialog(
   $dialog, 'info', 'close',
   $d->get(
'Multiple non-numerical values are not currently supported. Please file a bug.'
   )
  );
 }
 return;
}

sub _pack_widget {
 my ( $self,    $widget, $data ) = @_;
 my ( $options, $opt,    $hbox ) = @$data;
 if ( defined $widget ) {
  $opt->{widget} = $widget;
  if ( $opt->{type} == SANE_TYPE_BUTTON or $opt->{max_values} > 1 ) {
   $hbox->pack_end( $widget, TRUE, TRUE, 0 );
  }
  else {
   $hbox->pack_end( $widget, FALSE, FALSE, 0 );
  }
  $tooltips->set_tip( $widget, $d_sane->get( $opt->{desc} ) );

  # Look-up to hide/show the box if necessary
  $options->{box}{ $opt->{name} } = $hbox
    if ( _geometry_option($opt) );

  $self->_create_paper_widget($options);

 }
 else {
  $logger->warn("Unknown type $opt->{type}");
 }
 return;
}

# Update the sane option in the thread
# If necessary, reload the options,
# and walking the options tree, update the widgets

sub set_option {
 my ( $self, $option, $val ) = @_;
 $self->update_widget( $option->{name}, $val );

 my $current = $self->{current_scan_options};

 # Cache option
 push @$current, { $option->{name} => $val };

 # Note any duplicate options, keeping only the last entry.
 my %seen;

 my $j = $#{$current};
 while ( $j > -1 ) {
  my ($opt) =
    keys( %{ $current->[$j] } );
  $seen{$opt}++;
  if ( $seen{$opt} > 1 ) {
   splice @$current, $j, 1;
  }
  $j--;
 }
 $self->{current_scan_options} = $current;

 my $reload_triggers = $self->get('reload-triggers');
 $reload_triggers = [$reload_triggers]
   if ( ref($reload_triggers) ne 'ARRAY' );
 if (@$reload_triggers) {
  my $pbar;
  my $hboxd = $self->{hboxd};
  Gscan2pdf::Frontend::CLI->find_scan_options(
   prefix           => $self->get('prefix'),
   frontend         => $self->get('frontend'),
   device           => $self->get('device'),
   options          => $reload_triggers,
   started_callback => sub {

    # Set up ProgressBar
    $pbar = Gtk2::ProgressBar->new;
    $pbar->set_pulse_step(.1);
    $pbar->set_text( $d->get('Updating options') );
    $hboxd->pack_start( $pbar, TRUE, TRUE, 0 );
    $hboxd->hide_all;
    $hboxd->show;
    $pbar->show;
   },
   running_callback => sub {
    $pbar->pulse;
   },
   finished_callback => sub {
    my ($options) = @_;
    $pbar->destroy;
    $logger->info($options);
    $self->update_options($options) if ($options);

    $self->signal_emit( 'finished-process', 'find_scan_options' );

    # Unset the profile unless we are actively setting it
    $self->set( 'profile', undef ) unless ( $self->{setting_profile} );

    $self->signal_emit( 'changed-scan-option', $option->{name}, $val );
   },
   error_callback => sub {
    my ($message) = @_;
    $self->signal_emit( 'process-error', $message );
    $pbar->destroy;
    $logger->warn($message);
   },
  );
 }
 else {

  # Unset the profile unless we are actively setting it
  $self->set( 'profile', undef ) unless ( $self->{setting_profile} );

  $self->signal_emit( 'changed-scan-option', $option->{name}, $val );
 }
 return;
}

sub update_widget {
 my ( $self, $name, $value ) = @_;

 my ( $group, $vbox );
 my $opt    = $self->get('available-scan-options')->by_name($name);
 my $widget = $opt->{widget};

 # could be undefined for !($opt->{cap} & SANE_CAP_SOFT_DETECT)
 if ( defined $widget ) {
  $widget->signal_handler_block( $widget->{signal} );

  # HBox for option
  my $hbox = $widget->parent;
  $hbox->set_sensitive( ( not $opt->{cap} & SANE_CAP_INACTIVE )
     and $opt->{cap} & SANE_CAP_SOFT_SELECT );

  if ( $opt->{max_values} < 2 ) {

   # CheckButton
   if ( $opt->{type} == SANE_TYPE_BOOL )
   {    ## no critic (ProhibitCascadingIfElse)
    $widget->set_active($value)
      if ( _value_for_active_option( $value, $opt ) );
   }

   # SpinButton
   elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_RANGE ) {
    my ( $step, $page ) = $widget->get_increments;
    $step = 1;
    $step = $opt->{constraint}{quant} if ( $opt->{constraint}{quant} );
    $widget->set_range( $opt->{constraint}{min}, $opt->{constraint}{max} );
    $widget->set_increments( $step, $page );
    $widget->set_value($value)
      if ( _value_for_active_option( $value, $opt ) );
   }

   # ComboBox
   elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_STRING_LIST
    or $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST )
   {
    $widget->get_model->clear;
    my $index = 0;
    for ( my $i = 0 ; $i < @{ $opt->{constraint} } ; ++$i ) {
     $widget->append_text( $d_sane->get( $opt->{constraint}[$i] ) );
     $index = $i if ( defined $value and $opt->{constraint}[$i] eq $value );
    }
    $widget->set_active($index) if ( defined $index );
   }

   # Entry
   elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_NONE ) {
    $widget->set_text($value)
      if ( _value_for_active_option( $value, $opt ) );
   }
  }
  $widget->signal_handler_unblock( $widget->{signal} );
 }
 return;
}

# If setting an option triggers a reload, we need to update the options

sub update_options {
 my ( $self, $options ) = @_;

 # walk the widget tree and update them from the hash
 $logger->debug( "Sane->get_option_descriptor returned: ", Dumper($options) );

 my ( $group, $vbox );
 my $num_dev_options = $options->num_options;
 for ( my $i = 1 ; $i < $num_dev_options ; ++$i ) {
  my $opt = $options->by_index($i);
  $self->update_widget( $opt->{name}, $opt->{val} );
 }
 return;
}

sub _value_for_active_option {
 my ( $value, $opt ) = @_;
 return defined $value and not $opt->{cap} & SANE_CAP_INACTIVE;
}

# display Goo::Canvas with graph

sub set_options {
 my ( $self, $opt ) = @_;

 # Set up the canvas
 my $window = Gscan2pdf::Dialog->new(
  'transient-for' => $self,
  title           => $d_sane->get( $opt->{title} ),
  destroy         => TRUE,
  border_width    => $self->get('border_width'),
 );
 my $vbox   = $window->vbox;
 my $canvas = Goo::Canvas->new;
 my ( $cwidth, $cheight ) = ( 200, 200 );
 $canvas->set_size_request( $cwidth, $cheight );
 $canvas->{border} = 10;
 $vbox->add($canvas);
 my $root = $canvas->get_root_item;

 $canvas->signal_connect(
  'button-press-event' => sub {
   my ( $widget, $event ) = @_;
   if ( defined $widget->{selected} ) {
    $widget->{selected}->set( 'fill-color' => 'black' );
    undef $widget->{selected};
   }
   return FALSE
     if ( $#{ $widget->{val} } + 1 >= $opt->{max_values}
    or $widget->{on_val} );
   my $fleur = Gtk2::Gdk::Cursor->new('fleur');
   my ( $x, $y ) = to_graph( $widget, $event->x, $event->y );
   $x = int($x) + 1;
   splice @{ $widget->{val} }, $x, 0, $y;
   splice @{ $widget->{items} }, $x, 0, add_value( $root, $widget );
   update_graph($widget);
   return TRUE;
  }
 );

 $canvas->signal_connect_after(
  'key_press_event',
  sub {
   my ( $widget, $event ) = @_;
   if (
    $event->keyval ==
    $Gtk2::Gdk::Keysyms{Delete}    ## no critic (ProhibitPackageVars)
    and defined $widget->{selected}
     )
   {
    my $item = $widget->{selected};
    undef $widget->{selected};
    $widget->{on_val} = FALSE;
    splice @{ $widget->{val} },   $item->{index}, 1;
    splice @{ $widget->{items} }, $item->{index}, 1;
    my $parent = $item->get_parent;
    my $num    = $parent->find_child($item);
    $parent->remove_child($num);
    update_graph($widget);
   }
   return FALSE;
  }
 );
 $canvas->can_focus(TRUE);
 $canvas->grab_focus($root);

 $canvas->{opt} = $opt;

 $canvas->{val} = $canvas->{opt}->{val};
 for ( @{ $canvas->{val} } ) {
  push @{ $canvas->{items} }, add_value( $root, $canvas );
 }

 if ( $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST ) {
  @{ $opt->{constraint} } = sort { $a <=> $b } @{ $opt->{constraint} };
 }

 # HBox for buttons
 my $hbox = Gtk2::HBox->new;
 $vbox->pack_start( $hbox, FALSE, TRUE, 0 );

 # Apply button
 my $abutton = Gtk2::Button->new_from_stock('gtk-apply');
 $hbox->pack_start( $abutton, TRUE, TRUE, 0 );
 $abutton->signal_connect(
  clicked => sub {
   $self->set_option( $opt, $canvas->{val} );

 # when INFO_INEXACT is implemented, so that the value is reloaded, check for it
 # here, so that the reloaded value is not overwritten.
   $opt->{val} = $canvas->{val};
   $window->destroy;
  }
 );

 # Cancel button
 my $cbutton = Gtk2::Button->new_from_stock('gtk-cancel');
 $hbox->pack_end( $cbutton, FALSE, FALSE, 0 );
 $cbutton->signal_connect( clicked => sub { $window->destroy } );

# Have to show the window before updating it otherwise is doesn't know how big it is
 $window->show_all;
 update_graph($canvas);
 return;
}

sub add_value {
 my ( $root, $canvas ) = @_;
 my $item = Goo::Canvas::Rect->new(
  $root, 0, 0, 10, 10,
  'fill-color' => 'black',
  'line-width' => 0,
 );
 $item->signal_connect(
  'enter-notify-event' => sub {
   $canvas->{on_val} = TRUE;
   return TRUE;
  }
 );
 $item->signal_connect(
  'leave-notify-event' => sub {
   $canvas->{on_val} = FALSE;
   return TRUE;
  }
 );
 $item->signal_connect(
  'button-press-event' => sub {
   my ( $widget, $target, $ev ) = @_;
   $canvas->{selected} = $item;
   $item->set( 'fill-color' => 'red' );
   my $fleur = Gtk2::Gdk::Cursor->new('fleur');
   $widget->get_canvas->pointer_grab( $widget,
    [ 'pointer-motion-mask', 'button-release-mask' ],
    $fleur, $ev->time );
   return TRUE;
  }
 );
 $item->signal_connect(
  'button-release-event' => sub {
   my ( $widget, $target, $ev ) = @_;
   $widget->get_canvas->pointer_ungrab( $widget, $ev->time );
   return TRUE;
  }
 );
 my $opt = $canvas->{opt};
 $item->signal_connect(
  'motion-notify-event' => sub {
   my ( $widget, $target, $event ) = @_;
   return FALSE
     unless ## no critic (ProhibitNegativeExpressionsInUnlessAndUntilConditions)
     (
    $event->state >=    ## no critic (ProhibitMismatchedOperators)
    'button1-mask'
     );
   my ( $x, $y ) = ( $event->x, $event->y );
   my ( $xgr, $ygr ) = ( 0, $y );
   if ( $opt->{constraint_type} == SANE_CONSTRAINT_RANGE ) {
    ( $xgr, $ygr ) = to_graph( $canvas, 0, $y );
    if ( $ygr > $opt->{constraint}{max} ) {
     $ygr = $opt->{constraint}{max};
    }
    elsif ( $ygr < $opt->{constraint}{min} ) {
     $ygr = $opt->{constraint}{min};
    }
   }
   elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST ) {
    ( $xgr, $ygr ) = to_graph( $canvas, 0, $y );
    for ( my $i = 1 ; $i < @{ $opt->{constraint} } ; $i++ ) {
     if ( $ygr < ( $opt->{constraint}[$i] + $opt->{constraint}[ $i - 1 ] ) / 2 )
     {
      $ygr = $opt->{constraint}[ $i - 1 ];
      last;
     }
     elsif ( $i == $#{ $opt->{constraint} } ) {
      $ygr = $opt->{constraint}[$i];
     }
    }
   }
   $canvas->{val}[ $widget->{index} ] = $ygr;
   ( $x, $y ) = to_canvas( $canvas, $xgr, $ygr );
   $widget->set( y => $y - 10 / 2 );
   return TRUE;
  }
 );
 return $item;
}

# convert from graph co-ordinates to canvas co-ordinates

sub to_canvas {
 my ( $canvas, $x, $y ) = @_;
 return ( $x - $canvas->{bounds}[0] ) * $canvas->{scale}[0] + $canvas->{border},
   $canvas->{cheight} -
   ( $y - $canvas->{bounds}[1] ) * $canvas->{scale}[1] -
   $canvas->{border};
}

# convert from canvas co-ordinates to graph co-ordinates

sub to_graph {
 my ( $canvas, $x, $y ) = @_;
 return ( $x - $canvas->{border} ) / $canvas->{scale}[0] + $canvas->{bounds}[0],
   ( $canvas->{cheight} - $y - $canvas->{border} ) / $canvas->{scale}[1] +
   $canvas->{bounds}[1];
}

sub update_graph {
 my ($canvas) = @_;

 # Calculate bounds of graph
 my @bounds;
 for ( @{ $canvas->{val} } ) {
  $bounds[1] = $_ if ( not defined $bounds[1] or $_ < $bounds[1] );
  $bounds[3] = $_ if ( not defined $bounds[3] or $_ > $bounds[3] );
 }
 my $opt = $canvas->{opt};
 $bounds[0] = 0;
 $bounds[2] = $#{ $canvas->{val} };
 if ( $bounds[0] >= $bounds[2] ) {
  $bounds[0] = -0.5;
  $bounds[2] = 0.5;
 }
 if ( $opt->{constraint_type} == SANE_CONSTRAINT_RANGE ) {
  $bounds[1] = $opt->{constraint}{min};
  $bounds[3] = $opt->{constraint}{max};
 }
 elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST ) {
  $bounds[1] = $opt->{constraint}[0];
  $bounds[3] = $opt->{constraint}[ $#{ $opt->{constraint} } ];
 }
 my ( $vwidth, $vheight ) =
   ( $bounds[2] - $bounds[0], $bounds[3] - $bounds[1] );

 # Calculate bounds of canvas
 my ( $x, $y, $cwidth, $cheight ) = $canvas->allocation->values;

 # Calculate scale factors
 my @scale = (
  ( $cwidth - $canvas->{border} * 2 ) / $vwidth,
  ( $cheight - $canvas->{border} * 2 ) / $vheight
 );

 $canvas->{scale}   = \@scale;
 $canvas->{bounds}  = \@bounds;
 $canvas->{cheight} = $cheight;

 # Update canvas
 for ( my $i = 0 ; $i <= $#{ $canvas->{items} } ; $i++ ) {
  my $item = $canvas->{items}[$i];
  $item->{index} = $i;
  my ( $xc, $yc ) = to_canvas( $canvas, $i, $canvas->{val}[$i] );
  $item->set( x => $xc - 10 / 2, y => $yc - 10 / 2 );
 }
 return;
}

# roll my own Data::Dumper to walk the reference tree without printing the results

sub my_dumper {
 my ($ref) = @_;
 given ( ref $ref ) {
  when ('ARRAY') {
   for (@$ref) {
    my_dumper($_);
   }
  }
  when ('HASH') {
   while ( my ( $key, $val ) = each(%$ref) ) {
    my_dumper($val);
   }
  }
 }
 return;
}

# Set options to profile referenced by hashref

sub set_current_scan_options {
 my ( $self, $profile ) = @_;

 return unless ( defined $profile );

 # Move them first to a dummy array, as otherwise it would be self-modifying
 my $defaults;

 # Config::General flattens arrays with 1 entry to scalars,
 # so we must check for this
 if ( ref($profile) ne 'ARRAY' ) {
  push @$defaults, $profile;
 }
 else {
  @$defaults = @$profile;
 }

 # As scanimage and scanadf rename the geometry options,
 # we have to map them back to the original names
 map_geometry_names($defaults);

 # Give the GUI a chance to catch up between settings,
 # in case they have to be reloaded.
 # Use the 'changed-scan-option' signal to trigger the next loop
 my $i = 0;

 my ( $changed_scan_signal, $changed_paper_signal );
 $changed_scan_signal = $self->signal_connect(
  'changed-scan-option' => sub {
   my ( $widget, $name, $val ) = @_;

   # for reasons I don't understand, without walking the reference tree,
   # parts of $default are undef
   my_dumper($defaults);
   my ( $ename, $eval ) = each( %{ $defaults->[$i] } );

   # don't check $eval against $val, just in case they are different
   if ( $ename eq $name ) {
    $i++;
    $i =
      $self->_set_option_emit_signal( $i, $defaults, $changed_scan_signal,
     $changed_paper_signal );
   }
  }
 );
 $changed_paper_signal = $self->signal_connect(
  'changed-paper' => sub {
   my ( $widget, $val ) = @_;

   # for reasons I don't understand, without walking the reference tree,
   # parts of $default are undef
   my_dumper($defaults);
   my ( $ename, $eval ) = each( %{ $defaults->[$i] } );

   if ( $eval eq $val ) {
    $i++;
    $i =
      $self->_set_option_emit_signal( $i, $defaults, $changed_scan_signal,
     $changed_paper_signal );
   }
  }
 );
 $i =
   $self->_set_option_emit_signal( $i, $defaults, $changed_scan_signal,
  $changed_paper_signal );
 return;
}

# Helper sub to reduce code duplication

sub _set_option_emit_signal {
 my ( $self, $i, $defaults, $signal1, $signal2 ) = @_;
 $i = $self->set_option_widget( $i, $defaults ) if ( $i < @$defaults );

 # Only emit the changed-current-scan-options signal when we have finished
 if ( ( not defined($i) or $i > $#{$defaults} )
  and $self->signal_handler_is_connected($signal1)
  and $self->signal_handler_is_connected($signal2) )
 {
  $self->signal_handler_disconnect($signal1);
  $self->signal_handler_disconnect($signal2);
  $self->set( 'profile', undef ) unless ( $self->{setting_profile} );
  $self->signal_emit( 'changed-current-scan-options',
   $self->get('current-scan-options') );
 }
 return $i;
}

# Extract a option value from a profile

sub _get_option_from_profile {
 my ( $name, $profile ) = @_;

 # for reasons I don't understand, without walking the reference tree,
 # parts of $profile are undef
 my_dumper($profile);
 for (@$profile) {
  my ( $key, $val ) = each(%$_);
  return $val if ( $key eq $name );
 }
 return;
}

# Set option widget

sub set_option_widget {
 my ( $self, $i, $profile ) = @_;

 while ( $i < @$profile ) {

  # for reasons I don't understand, without walking the reference tree,
  # parts of $profile are undef
  my_dumper( $profile->[$i] );
  my ( $name, $val ) = each( %{ $profile->[$i] } );

  if ( $name eq 'Paper size' ) {
   $self->set( 'paper', $val );
   return $self->set_option_widget( $i + 1, $profile );
  }

  my $options = $self->get('available-scan-options');
  my $opt     = $options->by_name($name);
  my $widget  = $opt->{widget};

  if ( ref($val) eq 'ARRAY' ) {
   $self->set_option( $opt, $val );

   # when INFO_INEXACT is implemented, so that the value is reloaded,
   # check for it here, so that the reloaded value is not overwritten.
   $opt->{val} = $val;
  }
  else {
   given ($widget) {
    when ( $widget->isa('Gtk2::CheckButton') ) {
     $val = SANE_FALSE if ( $val eq '' );
     if ( $widget->get_active != $val ) {
      $widget->set_active($val);
      return $i;
     }
    }
    when ( $widget->isa('Gtk2::SpinButton') ) {
     if ( $widget->get_value != $val ) {
      $widget->set_value($val);
      return $i;
     }
    }
    when ( $widget->isa('Gtk2::ComboBox') ) {
     if ( $opt->{constraint}[ $widget->get_active ] ne $val ) {
      my $index;
      for ( my $j = 0 ; $j < @{ $opt->{constraint} } ; ++$j ) {
       $index = $j if ( $opt->{constraint}[$j] eq $val );
      }
      $widget->set_active($index) if ( defined $index );
      return $i;
     }
    }
    when ( $widget->isa('Gtk2::Entry') ) {
     if ( $widget->get_text ne $val ) {
      $widget->set_text($val);
      return $i;
     }
    }
   }
  }
  ++$i;
 }

 return;
}

# As scanimage and scanadf rename the geometry options,
# we have to map them back to the original names
sub map_geometry_names {
 my ($profile) = @_;
 for my $i ( 0 .. $#{$profile} ) {

  # for reasons I don't understand, without walking the reference tree,
  # parts of $profile are undef
  my_dumper($profile);
  my ( $name, $val ) = each %{ $profile->[$i] };
  given ($name) {
   when (SANE_NAME_SCAN_TL_X) {
    $name = 'l';
    $profile->[$i] = { $name => $val };
   }
   when (SANE_NAME_SCAN_TL_Y) {
    $name = 't';
    $profile->[$i] = { $name => $val };
   }
   when (SANE_NAME_SCAN_BR_X) {
    $name = 'x';
    my $l = _get_option_from_profile( 'l', $profile );
    $l = _get_option_from_profile( SANE_NAME_SCAN_TL_X, $profile )
      unless ( defined $l );
    $val -= $l if ( defined $l );
    $profile->[$i] = { $name => $val };
   }
   when (SANE_NAME_SCAN_BR_Y) {
    $name = 'y';
    my $t = _get_option_from_profile( 't', $profile );
    $t = _get_option_from_profile( SANE_NAME_SCAN_TL_Y, $profile )
      unless ( defined $t );
    $val -= $t if ( defined $t );
    $profile->[$i] = { $name => $val };
   }
  }
 }
 return;
}

sub scan {
 my ($self) = @_;

 # Get selected number of pages
 my $npages = $self->get('num-pages');
 my $start  = $self->get('page-number-start');
 my $step   = $self->get('page-number-increment');
 $npages = $self->get('max-pages')
   if ( $npages > 0 and $step < 0 );

 if ( $start == 1 and $step < 0 ) {
  $self->signal_emit( 'process-error',
   $d->get('Must scan facing pages first') );
  return TRUE;
 }

 # As scanimage and scanadf rename the geometry options,
 # we have to map them back to the original names
 my $options = $self->{current_scan_options};
 map_geometry_names($options);

 # Remove paper size from options
 my @options;
 for (@$options) {

  # for reasons I don't understand, without walking the reference tree,
  # parts of $_ are undef
  my_dumper($_);
  my ( $key, $val ) = each(%$_);
  push @options, { $key => $val } unless ( $key eq 'Paper size' );
 }

 my $i = 1;
 Gscan2pdf::Frontend::CLI->scan_pages(
  device           => $self->get('device'),
  dir              => $self->get('dir'),
  format           => "out%d.pnm",
  options          => \@options,
  npages           => $npages,
  start            => $start,
  step             => $step,
  started_callback => sub {
   $self->signal_emit( 'started-process', make_progress_string( $i, $npages ) );
  },
  running_callback => sub {
   my ($progress) = @_;
   $self->signal_emit( 'changed-progress', $progress, undef );
  },
  finished_callback => sub {
   $self->signal_emit( 'finished-process', 'scan_pages' );
  },
  new_page_callback => sub {
   my ($n) = @_;
   $self->signal_emit( 'new-scan', $n );
   $self->signal_emit( 'changed-progress', 0,
    make_progress_string( ++$i, $npages ) );
  },
  error_callback => sub {
   my ($msg) = @_;
   $self->signal_emit( 'process-error', $msg );
  }
 );
 return;
}

sub make_progress_string {
 my ( $i, $npages ) = @_;
 return sprintf $d->get("Scanning page %d of %d"), $i, $npages
   if ( $npages > 0 );
 return sprintf $d->get("Scanning page %d"), $i;
}

sub cancel_scan {
 Gscan2pdf::Frontend::Sane->cancel_scan;
 $logger->info("Cancelled scan");
 return;
}

1;

__END__
