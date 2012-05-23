package Gscan2pdf::Scanner::Dialog;

use warnings;
use strict;
use Gscan2pdf::Dialog;
use Glib qw(TRUE FALSE);   # To get TRUE and FALSE
use Sane 0.05;             # To get SANE_NAME_PAGE_WIDTH & SANE_NAME_PAGE_HEIGHT
use Gscan2pdf::Frontend::Sane;
use Locale::gettext 1.05;    # For translations
use feature "switch";

BEGIN {
 use Gscan2pdf::Scanner::Options
   ;    # need to register this with Glib before we can use it below
}

# from http://gtk2-perl.sourceforge.net/doc/subclassing_widgets_in_perl.html
use Glib::Object::Subclass Gscan2pdf::Dialog::, signals => {
 'new-scan' => {
  param_types => ['Glib::UInt'],    # page number
  return_type => undef
 },
 'changed-device' => {
  param_types => ['Glib::String'],    # device name
  return_type => undef
 },
 'changed-device-list' => {
  param_types => ['Glib::Scalar'],    # array of hashes with device info
  return_type => undef
 },
 'changed-num-pages' => {
  param_types => ['Glib::UInt'],      # new number of pages to scan
  return_type => undef
 },
 'changed-page-number-start' => {
  param_types => ['Glib::UInt'],      # new start page
  return_type => undef
 },
 'changed-page-number-increment' => {
  param_types => ['Glib::UInt'],      # new increment
  return_type => undef
 },
 'changed-scan-option' => {
  param_types => [ 'Glib::Scalar', 'Glib::Scalar' ],    # name, value
  return_type => undef
 },
 'changed-current-scan-options' => {
  param_types => ['Glib::Scalar'],                      # profile array
  return_type => undef
 },
 'reloaded-scan-options' => {},
 'changed-profile'       => {
  param_types => ['Glib::Scalar'],                      # name
  return_type => undef
 },
 'added-profile' => {
  param_types => [ 'Glib::Scalar', 'Glib::Scalar' ],    # name, profile array
  return_type => undef
 },
 'removed-profile' => {
  param_types => ['Glib::Scalar'],                      # name
  return_type => undef
 },
 'changed-paper' => {
  param_types => ['Glib::Scalar'],                      # name
  return_type => undef
 },
 'changed-paper-formats' => {
  param_types => ['Glib::Scalar'],                      # formats
  return_type => undef
 },
 'started-process' => {
  param_types => ['Glib::Scalar'],                      # message
  return_type => undef
 },
 'changed-progress' => {
  param_types => [ 'Glib::Scalar', 'Glib::Scalar' ],    # progress, message
  return_type => undef
 },
 'finished-process' => {},
 'process-error'    => {
  param_types => ['Glib::Scalar'],                      # error message
  return_type => undef
 },
 show => \&show,
  },
  properties => [
 Glib::ParamSpec->string(
  'device',                                             # name
  'Device',                                             # nick
  'Device name',                                        # blurb
  '',                                                   # default
  [qw/readable writable/]                               # flags
 ),
 Glib::ParamSpec->scalar(
  'device-list',                                        # name
  'Device list',                                        # nick
  'Array of hashes of available devices',               # blurb
  [qw/readable writable/]                               # flags
 ),
 Glib::ParamSpec->scalar(
  'dir',                                                # name
  'Directory',                                          # nick
  'Directory in which to store scans',                  # blurb
  [qw/readable writable/]                               # flags
 ),
 Glib::ParamSpec->scalar(
  'logger',                                             # name
  'Logger',                                             # nick
  'Log::Log4perl::get_logger object',                   # blurb
  [qw/readable writable/]                               # flags
 ),
 Glib::ParamSpec->scalar(
  'profile',                                            # name
  'Profile',                                            # nick
  'Name of current profile',                            # blurb
  [qw/readable writable/]                               # flags
 ),
 Glib::ParamSpec->string(
  'paper',                                              # name
  'Paper',                                              # nick
  'Name of currently selected paper format',            # blurb
  '',                                                   # default
  [qw/readable writable/]                               # flags
 ),
 Glib::ParamSpec->scalar(
  'paper-formats',                                                   # name
  'Paper formats',                                                   # nick
  'Hash of arrays defining paper formats, e.g. A4, Letter, etc.',    # blurb
  [qw/readable writable/]                                            # flags
 ),
 Glib::ParamSpec->int(
  'num-pages',                        # name
  'Number of pages',                  # nickname
  'Number of pages to be scanned',    # blurb
  0,                                  # min 0 implies all
  999,                                # max
  1,                                  # default
  [qw/readable writable/]             # flags
 ),
 Glib::ParamSpec->int(
  'max-pages',                        # name
  'Maximum number of pages',          # nickname
'Maximum number of pages that can be scanned with current page-number-start and page-number-increment'
  ,                                   # blurb
  0,                                  # min 0 implies all
  999,                                # max
  0,                                  # default
  [qw/readable writable/]             # flags
 ),
 Glib::ParamSpec->int(
  'page-number-start',                          # name
  'Starting page number',                       # nickname
  'Page number of first page to be scanned',    # blurb
  1,                                            # min
  999,                                          # max
  1,                                            # default
  [qw/readable writable/]                       # flags
 ),
 Glib::ParamSpec->int(
  'page-number-increment',                                           # name
  'Page number increment',                                           # nickname
  'Amount to increment page number when scanning multiple pages',    # blurb
  -99,                                                               # min
  99,                                                                # max
  1,                                                                 # default
  [qw/readable writable/]                                            # flags
 ),
 Glib::ParamSpec->object(
  'available-scan-options',                                          # name
  'Scan options available',                                          # nickname
  'Scan options currently available, whether active, selected, or not',  # blurb
  'Gscan2pdf::Scanner::Options',    # package
  [qw/readable writable/]           # flags
 ),
 Glib::ParamSpec->scalar(
  'current-scan-options',                               # name
  'Current scan options',                               # nick
  'Array of scan options making up current profile',    # blurb
  [qw/readable writable/]                               # flags
 ),
  ];

my ( $d, $d_sane, $logger, $tooltips );
my $tolerance = 1;

sub INIT_INSTANCE {
 my $self = shift;

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
    $self->get_devices;
   }
   else {
    $self->scan_options( $device_list->[$index] );
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
   $self->set( 'num-pages', 0 );
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
   $self->set( 'num-pages', $spin_buttonn->get_value );
  }
 );

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
   $spin_buttoni->set_value( -$self->get('page-number-increment') )
     if ( $spin_buttoni->get_value == 0 );
   $self->set( 'page-number-increment', $spin_buttoni->get_value );
  }
 );

 # Check whether the start page exists
 $spin_buttons->signal_connect( 'value-changed' => \&update_start );

 # Setting this here to fire callback running update_start
 $spin_buttons->set_value( $self->get('page-number-start') );

 # Callback on changing number of pages
 $spin_buttonn->signal_connect(
  'value-changed' => sub {
   $self->set( 'num-pages', $spin_buttonn->get_value );
   $bscannum->set_active(TRUE);    # Set the radiobutton active

   # Check that there is room in the list for the number of pages
   update_number();
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
   if ( $combobs->get_active == 0 ) {
    $spin_buttoni->set_value(2);
   }
   else {
    $spin_buttoni->set_value(-2);
   }

 # FIXME: do this in a callback from a signal
 #   if ( $#{ $slist->{data} } > -1 ) {
 #    $spin_buttons->set_value( $slist->{data}[ $#{ $slist->{data} } ][0] + 1 );
 #   }
 #   else {
   $spin_buttons->set_value(1);

   #   }
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
   if ( $combobs->get_active == 0 ) {
    $spin_buttoni->set_value(2);
   }
   else {
    $spin_buttoni->set_value(-2);
   }

 # FIXME: do this in a callback from a signal
 #   if ( $#{ $slist->{data} } > -1 ) {
 #    $spin_buttons->set_value( $slist->{data}[ $#{ $slist->{data} } ][0] + 1 );
 #   }
 #   else {
   $spin_buttons->set_value(1);

   #   }
  }
 );

# Have to put the extended pagenumber checkbox here to reference simple controls
 $checkx->signal_connect(
  toggled => sub {
   if ( $checkx->get_active ) {
    $frames->hide_all;
    $self->{framex}->show_all;
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
    $self->{framex}->hide_all;
   }
  }
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

   if ( $dialog->run eq 'ok' and $entry->get_text !~ /^\s*$/ ) {
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
 return;
}

sub SET_PROPERTY {
 my ( $self, $pspec, $newval ) = @_;
 my $name   = $pspec->get_name;
 my $oldval = $self->get($name);
 $self->{$name} = $newval;
 if (( defined($newval) and defined($oldval) and $newval ne $oldval )
  or ( defined($newval) xor defined($oldval) ) )
 {
  given ($name) {
   when ('device') {
    $self->set_device($newval);
    $self->signal_emit( 'changed-device', $newval )
   }
   when ('device_list') {
    $self->set_device_list($newval);
    $self->signal_emit( 'changed-device-list', $newval )
   }
   when ('logger') { $logger = $self->get('logger') }
   when ('num_pages') { $self->signal_emit( 'changed-num-pages', $newval ) }
   when ('page_number_start') {
    $self->signal_emit( 'changed-page-number-start', $newval )
   }
   when ('page_number_increment') {
    $self->signal_emit( 'changed-page-number-increment', $newval )
   }
   when ('paper') {
    set_combobox_by_text( $self->{combobp}, $newval );
    $self->signal_emit( 'changed-paper', $newval )
   }
   when ('paper_formats') {
    $self->set_paper_formats($newval);
    $self->signal_emit( 'changed-paper-formats', $newval )
   }
   when ('profile') {
    $self->set_profile($newval);
   }
   when ('available_scan_options') {
    $self->signal_emit('reloaded-scan-options')
   }
   when ('current_scan_options') { $self->set_current_scan_options($newval) }
  }
 }
 return;
}

sub show {
 my $self = shift;
 $self->signal_chain_from_overridden;
 $self->{framex}->hide_all;
}

# Get number of rows in combobox
sub num_rows_combobox {
 my ($combobox) = @_;
 my $i = -1;
 $combobox->get_model->foreach( sub { $i++; return FALSE } );
 return $i;
}

# Run Sane->get_devices

sub get_devices {
 my ($self) = @_;

 my $pbar;
 my $hboxd = $self->{hboxd};
 Gscan2pdf::Frontend::Sane->get_devices(
  sub {

   # Set up ProgressBar
   $pbar = Gtk2::ProgressBar->new;
   $pbar->set_pulse_step(.1);
   $pbar->set_text( $d->get('Fetching list of devices') );
   $hboxd->pack_start( $pbar, TRUE, TRUE, 0 );
   $pbar->show;
  },
  sub {
   $pbar->pulse;
  },
  sub {
   my ($data) = @_;
   $pbar->destroy;
   my @device_list = @{$data};
   use Data::Dumper;
   $logger->info( "Sane->get_devices returned: ", Dumper( \@device_list ) );
   if ( @device_list == 0 ) {
    my $parent = $self->get('transient-for');
    $self->destroy;
    undef $self;
    main::show_message_dialog( $parent, 'error', 'close',
     $d->get('No devices found') );
    return FALSE;
   }
   $self->set( 'device-list', \@device_list );
  }
 );
 return;
}

sub set_device_list {
 my ( $self, $device_list ) = @_;

 # Note any duplicate device names and delete if necessary
 my %seen;
 my $i = 0;
 while ( $i < @$device_list ) {
  $seen{ $device_list->[$i]{name} }++;
  if ( $seen{ $device_list->[$i]{name} } > 1 ) {
   splice @$device_list, $i, 1;
  }
  else {
   $i++;
  }
 }

 # Note any duplicate model names and add the device if necessary
 undef %seen;
 for (@$device_list) {
  $seen{ $_->{model} }++;
 }
 for (@$device_list) {
  $_->{label} = "$_->{vendor} $_->{model}";
  $_->{label} .= " on $_->{name}" if ( $seen{ $_->{model} } > 1 );
 }

 $self->{combobd}->signal_handler_block( $self->{combobd_changed_signal} );

 # Remove all entries apart from rescan
 $i = get_combobox_num_items( $self->{combobd} );
 $self->{combobd}->remove_text(0) while ( $i-- > 1 );

 # read the model names into the combobox
 for (@$device_list) {
  $self->{combobd}->append_text( $_->{label} );
 }

 $self->{combobd}->signal_handler_unblock( $self->{combobd_changed_signal} );
 return;
}

sub set_device {
 my ( $self, $device ) = @_;
 if ( defined($device) and $device ne '' ) {
  my $o;
  my $device_list = $self->get('device_list');
  if ( defined $device_list ) {
   for ( my $i = 0 ; $i < @$device_list ; $i++ ) {
    $o = $i if ( $device eq $device_list->[$i]{name} );
   }
   $o = 0 unless ( defined $o );

   # Set the device dependent options after the number of pages
   #  to scan so that the source button callback can ghost the
   #  all button.
   # This then fires the callback, updating the options,
   #  so no need to do it further down.
   $self->{combobd}->set_active($o);
  }
 }
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

 my $signal;
 Gscan2pdf::Frontend::Sane->open_device(
  device_name      => $self->get('device'),
  started_callback => sub {
   $self->signal_emit( 'started-process', $d->get('Opening device') );
  },
  running_callback => sub {
   $self->signal_emit( 'changed-progress', -1, undef );
  },
  finished_callback => sub {
   $self->signal_emit('finished-process');
   Gscan2pdf::Frontend::Sane->find_scan_options(
    sub {    # started callback
     $self->signal_emit( 'started-process', $d->get('Retrieving options') );
    },
    sub {    # running callback
     $self->signal_emit( 'changed-progress', -1 );
    },
    sub {    # finished callback
     my ($data) = @_;
     my $options = Gscan2pdf::Scanner::Options->new_from_data($data);
     $logger->debug( "Sane->get_option_descriptor returned: ",
      Dumper($options) );

     my ( $group, $vbox, $hboxp );
     my $num_dev_options = $options->num_options;

     delete
       $self->{combobp};    # So we don't carry over from one device to another
     for ( my $i = 1 ; $i < $num_dev_options ; ++$i ) {
      my $opt = $options->by_index($i);

      # Notebook page for group
      if ( $opt->{type} == SANE_TYPE_GROUP or not defined($vbox) ) {
       $vbox = Gtk2::VBox->new;
       $group =
           $opt->{type} == SANE_TYPE_GROUP
         ? $d_sane->get( $opt->{title} )
         : $d->get('Scan Options');
       $self->{notebook}->append_page( $vbox, $group );
       next;
      }

      next if ( !( $opt->{cap} & SANE_CAP_SOFT_DETECT ) );

      # Widget
      my ( $widget, $val );
      $val = $opt->{val};

      if (
           ( $opt->{type} == SANE_TYPE_FIXED or $opt->{type} == SANE_TYPE_INT )
       and ( $opt->{unit} == SANE_UNIT_MM or $opt->{unit} == SANE_UNIT_PIXEL )
       and ( ( $opt->{name} eq SANE_NAME_SCAN_TL_X )
        or ( $opt->{name} eq SANE_NAME_SCAN_TL_Y )
        or ( $opt->{name} eq SANE_NAME_SCAN_BR_X )
        or ( $opt->{name} eq SANE_NAME_SCAN_BR_Y )
        or ( $opt->{name} eq SANE_NAME_PAGE_HEIGHT )
        or ( $opt->{name} eq SANE_NAME_PAGE_WIDTH ) )
        )
      {

       # Define HBox for paper size here
       # so that it can be put before first geometry option
       if ( not defined($hboxp) ) {
        $hboxp = Gtk2::HBox->new;
        $vbox->pack_start( $hboxp, FALSE, FALSE, 0 );
       }
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
       if ( $opt->{type} == SANE_TYPE_BOOL ) {
        $widget = Gtk2::CheckButton->new;
        $widget->set_active(TRUE) if ($val);
        $widget->{signal} = $widget->signal_connect(
         toggled => sub {
          my $val = $widget->get_active;
          $self->set_option( $opt, $val );
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
          my $val = $widget->get_value;
          $self->set_option( $opt, $val );
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
          my $val = $widget->get_text;
          $self->set_option( $opt, $val );
         }
        );
       }
      }
      else {    # $opt->{max_values} > 1
       $widget = Gtk2::Button->new( $d_sane->get( $opt->{title} ) );
       $widget->{signal} = $widget->signal_connect(
        clicked => sub {
         if ($opt->{type} == SANE_TYPE_FIXED
          or $opt->{type} == SANE_TYPE_INT )
         {
          if ( $opt->{constraint_type} == SANE_CONSTRAINT_NONE ) {
           main::show_message_dialog(
            $self, 'info', 'close',
            $d->get(
'Multiple unconstrained values are not currently supported. Please file a bug.'
            )
           );
          }
          else {
           $self->set_options($opt);
          }
         }
         else {
          main::show_message_dialog(
           $self, 'info', 'close',
           $d->get(
'Multiple non-numerical values are not currently supported. Please file a bug.'
           )
          );
         }
        }
       );
      }

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
         if ( $opt->{name} eq SANE_NAME_SCAN_BR_X
        or $opt->{name} eq SANE_NAME_SCAN_BR_Y
        or $opt->{name} eq SANE_NAME_SCAN_TL_X
        or $opt->{name} eq SANE_NAME_SCAN_TL_Y
        or $opt->{name} eq SANE_NAME_PAGE_HEIGHT
        or $opt->{name} eq SANE_NAME_PAGE_WIDTH );

# Only define the paper size once the rest of the geometry widget have been created
       if (
            defined( $options->{box}{ scalar(SANE_NAME_SCAN_BR_X) } )
        and defined( $options->{box}{ scalar(SANE_NAME_SCAN_BR_Y) } )
        and defined( $options->{box}{ scalar(SANE_NAME_SCAN_TL_X) } )
        and defined( $options->{box}{ scalar(SANE_NAME_SCAN_TL_Y) } )
        and ( not defined $options->by_name(SANE_NAME_PAGE_HEIGHT)
         or defined( $options->{box}{ scalar(SANE_NAME_PAGE_HEIGHT) } ) )
        and ( not defined $options->by_name(SANE_NAME_PAGE_WIDTH)
         or defined( $options->{box}{ scalar(SANE_NAME_PAGE_WIDTH) } ) )
        and not defined( $self->{combobp} )
         )
       {

        # Paper list
        my $label = Gtk2::Label->new( $d->get('Paper size') );
        $hboxp->pack_start( $label, FALSE, FALSE, 0 );

        $self->{combobp} = Gtk2::ComboBox->new_text;
        $self->{combobp}->append_text( $d->get('Manual') );
        $self->{combobp}->append_text( $d->get('Edit') );
        $tooltips->set_tip( $self->{combobp},
         $d->get('Selects or edits the paper size') );
        $hboxp->pack_end( $self->{combobp}, FALSE, FALSE, 0 );
        $self->{combobp}->set_active(0);
        $self->{combobp}->signal_connect(
         changed => sub {

          if ( $self->{combobp}->get_active_text eq $d->get('Edit') ) {
           $self->edit_paper;
          }
          elsif ( $self->{combobp}->get_active_text eq $d->get('Manual') ) {
           for (
            ( SANE_NAME_SCAN_TL_X, SANE_NAME_SCAN_TL_Y,
             SANE_NAME_SCAN_BR_X,   SANE_NAME_SCAN_BR_Y,
             SANE_NAME_PAGE_HEIGHT, SANE_NAME_PAGE_WIDTH
            )
             )
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

           $options->by_name(SANE_NAME_SCAN_TL_X)->{widget}
             ->set_value( $formats->{$paper}{l} );
           $options->by_name(SANE_NAME_SCAN_TL_Y)->{widget}
             ->set_value( $formats->{$paper}{t} );
           $options->by_name(SANE_NAME_SCAN_BR_X)->{widget}
             ->set_value( $formats->{$paper}{x} + $formats->{$paper}{l} );
           $options->by_name(SANE_NAME_SCAN_BR_Y)->{widget}
             ->set_value( $formats->{$paper}{y} + $formats->{$paper}{t} );
           Glib::Idle->add(
            sub {
             for (
              ( SANE_NAME_SCAN_TL_X, SANE_NAME_SCAN_TL_Y,
               SANE_NAME_SCAN_BR_X,   SANE_NAME_SCAN_BR_Y,
               SANE_NAME_PAGE_HEIGHT, SANE_NAME_PAGE_WIDTH
              )
               )
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

      }
      else {
       $logger->warn("Unknown type $opt->{type}");
      }
     }

     # Set defaults
     my $sane_device = Gscan2pdf::Frontend::Sane->device();

     # Show new pages
     for ( my $i = 1 ; $i < $self->{notebook}->get_n_pages ; $i++ ) {
      $self->{notebook}->get_nth_page($i)->show_all;
     }

     # Give the GUI a chance to catch up before resizing.
     Glib::Idle->add( sub { $self->resize( 100, 100 ); } );

     $self->{sbutton}->set_sensitive(TRUE);
     $self->{sbutton}->grab_focus;

     $self->signal_emit('finished-process');

     # This fires the reloaded-scan-options signal,
     # so don't set this until we have finished
     $self->set( 'available-scan-options', $options );
    },
    sub {    # error callback
     my ($message) = @_;
     my $parent = $self->get('transient-for');
     $self->destroy;
     main::show_message_dialog( $parent, 'error', 'close',
      $d->get( 'Error retrieving scanner options: ' . $message ) );
    }
   );
  },
  error_callback => sub {
   my ($message) = @_;
   my $parent = $self->get('transient-for');
   $self->destroy;
   main::show_message_dialog( $parent, 'error', 'close',
    $d->get( 'Error opening device: ' . $message ) );
  }
 );

 return;
}

# Update the sane option in the thread
# If necessary, reload the options,
# and walking the options tree, update the widgets

sub set_option {
 my ( $self, $option, $val ) = @_;

 # Unset the profile unless we are actively setting it
 $self->set( 'profile', undef ) unless ( $self->{setting_profile} );

 my $current = $self->{current_scan_options};

 # Cache option
 push @$current, { $option->{name} => $val };

 # Note any duplicate options, keeping only the last entry.
 my %seen;

 my $j = $#{$current};
 while ( $j > -1 ) {
  my ($option) =
    keys( %{ $current->[$j] } );
  $seen{$option}++;
  if ( $seen{$option} > 1 ) {
   splice @$current, $j, 1;
  }
  $j--;
 }
 $self->{current_scan_options} = $current;

 my $signal;
 my $options = $self->get('available-scan-options');
 Gscan2pdf::Frontend::Sane->set_option(
  index            => $option->{index},
  value            => $val,
  started_callback => sub {
   $self->signal_emit( 'started-process', sprintf $d->get('Setting option %s'),
    $option->{name} );
  },
  running_callback => sub {
   $self->signal_emit( 'changed-progress', -1 );
  },
  finished_callback => sub {
   my ($data) = @_;

   if ($data) {

    # walk the widget tree and update them from the hash
    my @options = @{$data};
    $logger->debug( "Sane->get_option_descriptor returned: ",
     Dumper( \@options ) );

    my ( $group, $vbox );
    my $num_dev_options = $#options + 1;
    for ( my $i = 1 ; $i < $num_dev_options ; ++$i ) {
     my $widget = $options->by_index($i)->{widget};

     # could be undefined for !($opt->{cap} & SANE_CAP_SOFT_DETECT)
     if ( defined $widget ) {
      my $opt = $options[$i];
      my $val = $opt->{val};
      $widget->signal_handler_block( $widget->{signal} );

      # HBox for option
      my $hbox = $widget->parent;
      $hbox->set_sensitive( ( not $opt->{cap} & SANE_CAP_INACTIVE )
         and $opt->{cap} & SANE_CAP_SOFT_SELECT );

      if ( $opt->{max_values} < 2 ) {

       # CheckButton
       if ( $opt->{type} == SANE_TYPE_BOOL ) {
        $widget->set_active($val)
          if ( defined $val and not $opt->{cap} & SANE_CAP_INACTIVE );
       }

       # SpinButton
       elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_RANGE ) {
        my ( $step, $page ) = $widget->get_increments;
        $step = 1;
        $step = $opt->{constraint}{quant} if ( $opt->{constraint}{quant} );
        $widget->set_range( $opt->{constraint}{min}, $opt->{constraint}{max} );
        $widget->set_increments( $step, $page );
        $widget->set_value($val)
          if ( defined $val and not $opt->{cap} & SANE_CAP_INACTIVE );
       }

       # ComboBox
       elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_STRING_LIST
        or $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST )
       {
        $widget->get_model->clear;
        my $index = 0;
        for ( my $i = 0 ; $i < @{ $opt->{constraint} } ; ++$i ) {
         $widget->append_text( $d_sane->get( $opt->{constraint}[$i] ) );
         $index = $i if ( defined $val and $opt->{constraint}[$i] eq $val );
        }
        $widget->set_active($index) if ( defined $index );
       }

       # Entry
       elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_NONE ) {
        $widget->set_text($val)
          if ( defined $val and not $opt->{cap} & SANE_CAP_INACTIVE );
       }
      }
      $widget->signal_handler_unblock( $widget->{signal} );
     }
    }
   }

   # We can carry on applying defaults now, if necessary.
   $self->{gui_updating} = FALSE;
   $self->signal_emit('finished-process');
  }
 );
 $self->signal_emit( 'changed-scan-option', $option->{name}, $val );
 return;
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
   my ( $canvas, $event ) = @_;
   if ( defined $canvas->{selected} ) {
    $canvas->{selected}->set( 'fill-color' => 'black' );
    undef $canvas->{selected};
   }
   return FALSE
     if ( $#{ $canvas->{val} } + 1 >= $opt->{max_values}
    or $canvas->{on_val} );
   my $fleur = Gtk2::Gdk::Cursor->new('fleur');
   my ( $x, $y ) = to_graph( $canvas, $event->x, $event->y );
   $x = int($x) + 1;
   splice @{ $canvas->{val} }, $x, 0, $y;
   splice @{ $canvas->{items} }, $x, 0, add_value( $root, $canvas );
   update_graph($canvas);
   return TRUE;
  }
 );

 $canvas->signal_connect_after(
  'key_press_event',
  sub {
   my ( $canvas, $event ) = @_;
   if ( $event->keyval == $Gtk2::Gdk::Keysyms{Delete}
    and defined $canvas->{selected} )
   {
    my $item = $canvas->{selected};
    undef $canvas->{selected};
    $canvas->{on_val} = FALSE;
    splice @{ $canvas->{val} },   $item->{index}, 1;
    splice @{ $canvas->{items} }, $item->{index}, 1;
    my $parent = $item->get_parent;
    my $num    = $parent->find_child($item);
    $parent->remove_child($num);
    update_graph($canvas);
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
   my ( $item, $target, $ev ) = @_;
   $item->get_canvas->pointer_ungrab( $item, $ev->time );
   return TRUE;
  }
 );
 my $opt = $canvas->{opt};
 $item->signal_connect(
  'motion-notify-event' => sub {
   my ( $item, $target, $event ) = @_;
   return FALSE unless ( $event->state >= 'button1-mask' );
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
   $canvas->{val}[ $item->{index} ] = $ygr;
   ( $x, $y ) = to_canvas( $canvas, $xgr, $ygr );
   $item->set( y => $y - 10 / 2 );
   return TRUE;
  }
 );
 return $item;
}

# convert from graph co-ordinates to canvas co-ordinates

sub to_canvas {
 my ( $canvas, $x, $y ) = @_;
 return ( $x - $canvas->{bounds}[0] ) * $canvas->{scale}[0] +
   $canvas->{border},
   $canvas->{cheight} -
   ( $y - $canvas->{bounds}[1] ) * $canvas->{scale}[1] -
   $canvas->{border};
}

# convert from canvas co-ordinates to graph co-ordinates

sub to_graph {
 my ( $canvas, $x, $y ) = @_;
 return ( $x - $canvas->{border} ) / $canvas->{scale}[0] +
   $canvas->{bounds}[0],
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
  my ( $x, $y ) = to_canvas( $canvas, $i, $canvas->{val}[$i] );
  $item->set( x => $x - 10 / 2, y => $y - 10 / 2 );
 }
 return;
}

sub set_profile {
 my ( $self, $name ) = @_;
 set_combobox_by_text( $self->{combobsp}, $name );
 if ( defined($name) and $name ne '' ) {
  my $profile = $self->{profiles}{$name};

  # If we are setting the profile, don't unset the profile name
  $self->{setting_profile} = TRUE;

  # Only emit the changed-profile signal when the GUI has caught up
  $self->signal_connect(
   'changed-current-scan-options' => sub {
    delete $self->{setting_profile};
    $self->signal_emit( 'changed-profile', $name );
   }
  );

  $self->set( 'current-scan-options', $profile );
 }
 return;
}

# Set options to profile referenced by hashref

sub set_current_scan_options {
 my ( $self, $profile ) = @_;
 use Data::Dumper;

 return unless ( defined $profile );

 # Move them first to a dummy array, as otherwise it would be self-modifying
 my @defaults;

 # Config::General flattens arrays with 1 entry to scalars,
 # so we must check for this
 if ( ref($profile) ne 'ARRAY' ) {
  push @defaults, $profile;
 }
 else {
  @defaults = @$profile;
 }

 $self->set( 'profile', undef ) unless ( $self->{setting_profile} );
 delete $self->{current_scan_options};

 # Give the GUI a chance to catch up between settings,
 # in case they have to be reloaded.
 # Can't do this in Glib::Idle->add as the GUI is also idle waiting for the
 # sane thread to return, so manually flagging each loop
 my $i = 0;

 # Timer will run until callback returns false
 my $timer = Glib::Timeout->add(
  100,
  sub {

   # wait until the options have been loaded and the gui has stopped updating
   my $options = $self->get('available-scan-options');
   if ( defined($options) and not $self->{gui_updating} ) {
    $self->{gui_updating} = TRUE;
    my ( $name, $val ) = each( %{ $defaults[$i] } );
    my $opt = $options->by_name($name);

    my $widget = $opt->{widget};
    if ( ref($val) eq 'ARRAY' ) {
     $self->set_option( $opt, $val );

     # when INFO_INEXACT is implemented, so that the value is reloaded,
     # check for it here, so that the reloaded value is not overwritten.
     $opt->{val} = $val;
    }
    elsif ( $widget->isa('Gtk2::CheckButton') ) {
     if ( $widget->get_active != $val ) {
      $widget->set_active($val);
     }
     else {
      $self->{gui_updating} = FALSE;
     }
    }
    elsif ( $widget->isa('Gtk2::SpinButton') ) {
     if ( $widget->get_value != $val ) {
      $widget->set_value($val);
     }
     else {
      $self->{gui_updating} = FALSE;
     }
    }
    elsif ( $widget->isa('Gtk2::ComboBox') ) {
     if ( $opt->{constraint}[ $widget->get_active ] ne $val ) {
      my $index;
      for ( my $i = 0 ; $i < @{ $opt->{constraint} } ; ++$i ) {
       $index = $i if ( $opt->{constraint}[$i] eq $val );
      }
      $widget->set_active($index) if ( defined $index );
     }
     else {
      $self->{gui_updating} = FALSE;
     }
    }
    elsif ( $widget->isa('Gtk2::Entry') ) {
     if ( $widget->get_text ne $val ) {
      $widget->set_text($val);
     }
     else {
      $self->{gui_updating} = FALSE;
     }
    }
    $i++;
    $self->signal_emit( 'changed-current-scan-options', $profile )
      unless ( $i < @defaults );
    return FALSE unless ( $i++ < @defaults );
   }
   return TRUE;
  }
 );

 return;
}

# Add paper size to combobox if scanner large enough

sub set_paper_formats {
 my ( $self, $formats ) = @_;
 $self->{ignored_paper_formats} = ();
 my $options = $self->get('available-scan-options');

 for ( keys %$formats ) {
  if ( $options->supports_paper( $formats->{$_}, $tolerance ) ) {
   $self->{combobp}->prepend_text($_);
  }
  else {
   push @{ $self->{ignored_paper_formats} }, $_;
  }
 }
 return;
}

# Paper editor
sub edit_paper {
 my ($self) = @_;

 my $combobp = $self->{combobp};
 my $options = $self->get('available-scan-options');
 my $formats = $self->get('paper-formats');

 my $window = Gscan2pdf::Dialog->new(
  'transient-for' => $self,
  title           => $d->get('Edit paper size'),
  border_width    => $self->get('border-width'),
 );
 my $vbox = $window->get('vbox');

 # Buttons for SimpleList
 my $hboxl = Gtk2::HBox->new;
 $vbox->pack_start( $hboxl, FALSE, FALSE, 0 );
 my $vboxb = Gtk2::VBox->new;
 $hboxl->pack_start( $vboxb, FALSE, FALSE, 0 );
 my $dbutton = Gtk2::Button->new_from_stock('gtk-add');
 $vboxb->pack_start( $dbutton, TRUE, FALSE, 0 );
 my $rbutton = Gtk2::Button->new_from_stock('gtk-remove');
 $vboxb->pack_end( $rbutton, TRUE, FALSE, 0 );

 # Set up a SimpleList
 my $slist = Gtk2::Ex::Simple::List->new(
  $d->get('Name')   => 'text',
  $d->get('Width')  => 'int',
  $d->get('Height') => 'int',
  $d->get('Left')   => 'int',
  $d->get('Top')    => 'int'
 );
 for ( keys %$formats ) {
  push @{ $slist->{data} },
    [
   $_,                $formats->{$_}{x}, $formats->{$_}{y},
   $formats->{$_}{l}, $formats->{$_}{t}
    ];
 }

 # Set everything to be editable
 for ( 0 .. 4 ) {
  $slist->set_column_editable( $_, TRUE );
 }
 $slist->get_column(0)->set_sort_column_id(0);

 # Add button callback
 $dbutton->signal_connect(
  clicked => sub {
   my @rows = $slist->get_selected_indices;
   $rows[0] = 0 if ( !@rows );
   my $name    = $slist->{data}[ $rows[0] ][0];
   my $version = 2;
   my $i       = 0;
   while ( $i < @{ $slist->{data} } ) {
    if ( $slist->{data}[$i][0] eq "$name ($version)" ) {
     ++$version;
     $i = 0;
    }
    else {
     ++$i;
    }
   }
   my @line = [
    "$name ($version)",
    $slist->{data}[ $rows[0] ][1],
    $slist->{data}[ $rows[0] ][2],
    $slist->{data}[ $rows[0] ][3],
    $slist->{data}[ $rows[0] ][4]
   ];
   splice @{ $slist->{data} }, $rows[0] + 1, 0, @line;
  }
 );

 # Remove button callback
 $rbutton->signal_connect(
  clicked => sub {
   my @rows = $slist->get_selected_indices;
   if ( $#rows == $#{ $slist->{data} } ) {
    main::show_message_dialog( $window, 'error', 'close',
     $d->get('Cannot delete all paper sizes') );
   }
   else {
    while (@rows) {
     splice @{ $slist->{data} }, shift(@rows), 1;
    }
   }
  }
 );

 # Set-up the callback to check that no two Names are the same
 $slist->get_model->signal_connect(
  'row-changed' => sub {
   my ( $model, $path, $iter ) = @_;
   for ( my $i = 0 ; $i < @{ $slist->{data} } ; $i++ ) {
    if ( $i != $path->to_string
     and $slist->{data}[ $path->to_string ][0] eq $slist->{data}[$i][0] )
    {
     my $name    = $slist->{data}[ $path->to_string ][0];
     my $version = 2;
     if ( $name =~ /(.*) \((\d+)\)/ ) {
      $name    = $1;
      $version = $2 + 1;
     }
     $slist->{data}[ $path->to_string ][0] = "$name ($version)";
     return;
    }
   }
  }
 );
 $hboxl->pack_end( $slist, FALSE, FALSE, 0 );

 # Buttons
 my $hboxb = Gtk2::HBox->new;
 $vbox->pack_start( $hboxb, FALSE, FALSE, 0 );
 my $abutton = Gtk2::Button->new_from_stock('gtk-apply');
 $abutton->signal_connect(
  clicked => sub {
   my %formats;
   for ( my $i = 0 ; $i < @{ $slist->{data} } ; $i++ ) {
    $formats{ $slist->{data}[$i][0] }{x} = $slist->{data}[$i][1];
    $formats{ $slist->{data}[$i][0] }{y} = $slist->{data}[$i][2];
    $formats{ $slist->{data}[$i][0] }{l} = $slist->{data}[$i][3];
    $formats{ $slist->{data}[$i][0] }{t} = $slist->{data}[$i][4];
   }

   # Remove all formats, leaving Manual and Edit
   $combobp->remove_text(0) while ( $combobp->get_active > 1 );

   # Add new definitions
   $self->set( 'paper-formats', \%formats );
   main::show_message_dialog(
    $window,
    'warning',
    'close',
    $d->get(
'The following paper sizes are too big to be scanned by the selected device:'
      )
      . ' '
      . join( ', ', @{ $self->{ignored_paper_formats} } )
   ) if ( @{ $self->{ignored_paper_formats} } );

   # Set the combobox back from Edit to the previous value
   set_combobox_by_text( $combobp, $self->get('paper') );

   $window->destroy;
  }
 );
 $hboxb->pack_start( $abutton, TRUE, FALSE, 0 );
 my $cbutton = Gtk2::Button->new_from_stock('gtk-cancel');
 $cbutton->signal_connect(
  clicked => sub {

   # Set the combobox back from Edit to the previous value
   set_combobox_by_text( $combobp, $self->get('paper') );

   $window->destroy;
  }
 );
 $hboxb->pack_end( $cbutton, TRUE, FALSE, 0 );
 $window->show_all;
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
  main::show_message_dialog( $self, 'error', 'cancel',
   $d->get('Must scan facing pages first') );
  return TRUE;
 }

 my $i = 1;
 Gscan2pdf::Frontend::Sane->scan_pages(
  dir              => $self->get('dir'),
  format           => "out%d.pnm",
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
   $self->signal_emit('finished-process');

   #   scan_options( $device_list[ $self->{combobd}->get_active ] )
   #     if ( $SETTING{'cycle sane handle'} );
  },
  new_page_callback => sub {
   my ($n) = @_;
   $i++;

   $self->signal_emit( 'new-scan', $n );
   $self->signal_emit( 'changed-progress', 0,
    make_progress_string( $i, $npages ) );
  },
  error_callback => sub {
   my ($msg) = @_;
   $self->signal_emit( 'process-error', $msg );
  }
 );

 #   scan_pages( $npages, $start, $step, $rotate_facing, $rotate_reverse,
 #    $SETTING{'unpaper on scan'},
 #    $SETTING{'OCR on scan'}
 #  );
}

sub make_progress_string {
 my ( $i, $npages ) = @_;
 return sprintf $d->get("Scanning page %d of %d"), $i, $npages
   if ( $npages > 0 );
 return sprintf $d->get("Scanning page %d"), $i;
}

sub add_profile {
 my ( $self, $name, $profile ) = @_;
 if ( defined($name) and defined($profile) ) {
  $self->{profiles}{$name} = ();
  for (@$profile) {
   push @{ $self->{profiles}{$name} }, $_;
  }
  $self->{combobsp}->append_text($name);
  $self->signal_emit( 'added-profile', $name, $self->{profiles}{$name} );
 }
 return;
}

sub remove_profile {
 my ( $self, $name ) = @_;
 if ( defined($name) and defined( $self->{profiles}{$name} ) ) {
  my $i = get_combobox_by_text( $self->{combobsp}, $name );
  if ( $i > -1 ) {
   $self->{combobsp}->remove_text($i);
   my $n = num_rows_combobox( $self->{combobsp} );
   $i = $n if ( $i > $n );
   $self->{combobsp}->set_active($i) if ( $i > -1 );
   $self->signal_emit( 'removed-profile', $name );
  }
 }
 return;
}

sub get_combobox_num_items {
 my ($combobox) = @_;
 return unless ( defined $combobox );
 my $i = 0;
 $combobox->get_model->foreach( sub { ++$i } );
 return $i;
}

sub get_combobox_by_text {
 my ( $combobox, $text ) = @_;
 return -1 unless ( defined($combobox) and defined($text) );
 my $o = -1;
 my $i = 0;
 $combobox->get_model->foreach(
  sub {
   my ( $model, $path, $iter ) = @_;
   if ( $model->get( $iter, 0 ) eq $text ) {
    $o = $i;
    return TRUE;
   }
   else {
    ++$i;
    return FALSE;
   }
  }
 );
 return $o;
}

sub set_combobox_by_text {
 my ( $combobox, $text ) = @_;
 my $i = get_combobox_by_text( $combobox, $text );
 $combobox->set_active($i) if ( $i > -1 );
 return;
}

1;

__END__
