package Gscan2pdf::Dialog::Scan;

use warnings;
use strict;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use Glib qw(TRUE FALSE);   # To get TRUE and FALSE
use Image::Sane ':all';    # To get SANE_NAME_PAGE_WIDTH & SANE_NAME_PAGE_HEIGHT
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Storable qw(dclone);
use feature 'switch';
use Gscan2pdf::Dialog;
use Gscan2pdf::Scanner::Options;
use Gscan2pdf::Scanner::Profile;
use Gscan2pdf::Translation '__';    # easier to extract strings with xgettext
use Readonly;
Readonly my $BORDER_WIDTH => 6;

my (
    $MAX_PAGES,        $MAX_INCREMENT, $DOUBLE_INCREMENT,
    $CANVAS_SIZE,      $CANVAS_BORDER, $CANVAS_POINT_SIZE,
    $CANVAS_MIN_WIDTH, $NO_INDEX,      $EMPTY
);

# need to register this with Glib before we can use it below
BEGIN {
    Glib::Type->register_enum( 'Gscan2pdf::Dialog::Scan::Side',
        qw(facing reverse) );
    Glib::Type->register_enum( 'Gscan2pdf::Dialog::Scan::Sided',
        qw(single double) );
    use Readonly;
    Readonly $MAX_PAGES         => 9999;
    Readonly $MAX_INCREMENT     => 99;
    Readonly $DOUBLE_INCREMENT  => 2;
    Readonly $CANVAS_SIZE       => 200;
    Readonly $CANVAS_BORDER     => 10;
    Readonly $CANVAS_POINT_SIZE => 10;
    Readonly $CANVAS_MIN_WIDTH  => 1;
    Readonly $NO_INDEX          => -1;
    $EMPTY = q{};
}

# from http://gtk2-perl.sourceforge.net/doc/subclassing_widgets_in_perl.html
use Glib::Object::Subclass Gscan2pdf::Dialog::, signals => {
    'new-scan' => {
        param_types => [ 'Glib::String', 'Glib::UInt' ], # filename, page number
    },
    'changed-device' => {
        param_types => ['Glib::String'],                 # device name
    },
    'changed-device-list' => {
        param_types => ['Glib::Scalar'],    # array of hashes with device info
    },
    'changed-num-pages' => {
        param_types => ['Glib::UInt'],      # new number of pages to scan
    },
    'changed-page-number-start' => {
        param_types => ['Glib::UInt'],      # new start page
    },
    'changed-page-number-increment' => {
        param_types => ['Glib::Int'],       # new increment
    },
    'changed-side-to-scan' => {
        param_types => ['Glib::String'],    # facing or reverse
    },
    'changed-scan-option' => {
        param_types => [ 'Glib::Scalar', 'Glib::Scalar', 'Glib::Scalar' ]
        ,                                   # name, value, profile uuid
    },
    'changed-option-visibility' => {
        param_types => ['Glib::Scalar'],    # array of options to hide
    },
    'changed-current-scan-options' => {
        param_types => [ 'Glib::Scalar', 'Glib::String' ], # profile array, UUID
    },
    'reloaded-scan-options' => {},
    'changed-profile'       => {
        param_types => ['Glib::Scalar'],                   # name
    },
    'added-profile' => {
        param_types => [ 'Glib::Scalar', 'Glib::Scalar' ], # name, profile array
    },
    'removed-profile' => {
        param_types => ['Glib::Scalar'],                   # name
    },
    'changed-paper' => {
        param_types => ['Glib::Scalar'],                   # name
    },
    'changed-paper-formats' => {
        param_types => ['Glib::Scalar'],                   # formats
    },
    'started-process' => {
        param_types => ['Glib::Scalar'],                   # message
    },
    'changed-progress' => {
        param_types => [ 'Glib::Scalar', 'Glib::Scalar' ],   # progress, message
    },
    'finished-process' => {
        param_types => ['Glib::String'],                     # process name
    },
    'process-error' => {
        param_types => [ 'Glib::String', 'Glib::String' ]
        ,    # process name, error message
    },
    show                  => \&show,
    'clicked-scan-button' => {},
  },
  properties => [
    Glib::ParamSpec->string(
        'device',                  # name
        'Device',                  # nick
        'Device name',             # blurb
        $EMPTY,                    # default
        [qw/readable writable/]    # flags
    ),
    Glib::ParamSpec->scalar(
        'device-list',                             # name
        'Device list',                             # nick
        'Array of hashes of available devices',    # blurb
        [qw/readable writable/]                    # flags
    ),
    Glib::ParamSpec->scalar(
        'dir',                                     # name
        'Directory',                               # nick
        'Directory in which to store scans',       # blurb
        [qw/readable writable/]                    # flags
    ),
    Glib::ParamSpec->scalar(
        'logger',                                  # name
        'Logger',                                  # nick
        'Log::Log4perl::get_logger object',        # blurb
        [qw/readable writable/]                    # flags
    ),
    Glib::ParamSpec->scalar(
        'profile',                                 # name
        'Profile',                                 # nick
        'Name of current profile',                 # blurb
        [qw/readable writable/]                    # flags
    ),
    Glib::ParamSpec->string(
        'paper',                                      # name
        'Paper',                                      # nick
        'Name of currently selected paper format',    # blurb
        $EMPTY,                                       # default
        [qw/readable writable/]                       # flags
    ),
    Glib::ParamSpec->scalar(
        'paper-formats',                                                 # name
        'Paper formats',                                                 # nick
        'Hash of arrays defining paper formats, e.g. A4, Letter, etc.',  # blurb
        [qw/readable writable/]                                          # flags
    ),
    Glib::ParamSpec->int(
        'num-pages',                        # name
        'Number of pages',                  # nickname
        'Number of pages to be scanned',    # blurb
        0,                                  # min 0 implies all
        $MAX_PAGES,                         # max
        1,                                  # default
        [qw/readable writable/]             # flags
    ),
    Glib::ParamSpec->int(
        'max-pages',                        # name
        'Maximum number of pages',          # nickname
'Maximum number of pages that can be scanned with current page-number-start and page-number-increment'
        ,                                   # blurb
        -1,                                 # min -1 implies all
        $MAX_PAGES,                         # max
        0,                                  # default
        [qw/readable writable/]             # flags
    ),
    Glib::ParamSpec->int(
        'page-number-start',                          # name
        'Starting page number',                       # nickname
        'Page number of first page to be scanned',    # blurb
        1,                                            # min
        $MAX_PAGES,                                   # max
        1,                                            # default
        [qw/readable writable/]                       # flags
    ),
    Glib::ParamSpec->int(
        'page-number-increment',                      # name
        'Page number increment',                      # nickname
        'Amount to increment page number when scanning multiple pages',  # blurb
        -$MAX_INCREMENT,                                                 # min
        $MAX_INCREMENT,                                                  # max
        1,                         # default
        [qw/readable writable/]    # flags
    ),
    Glib::ParamSpec->enum(
        'sided',                             # name
        'Sided',                             # nickname
        'Either single or double',           # blurb
        'Gscan2pdf::Dialog::Scan::Sided',    # type
        'single',                            # default
        [qw/readable writable/]              # flags
    ),
    Glib::ParamSpec->enum(
        'side-to-scan',                      # name
        'Side to scan',                      # nickname
        'Either facing or reverse',          # blurb
        'Gscan2pdf::Dialog::Scan::Side',     # type
        'facing',                            # default
        [qw/readable writable/]              # flags
    ),
    Glib::ParamSpec->object(
        'available-scan-options',            # name
        'Scan options available',            # nickname
        'Scan options currently available, whether active, selected, or not'
        ,                                    # blurb
        'Gscan2pdf::Scanner::Options',       # package
        [qw/readable writable/]              # flags
    ),
    Glib::ParamSpec->object(
        'current-scan-options',                      # name
        'Current scan options',                      # nickname
        'Scan options making up current profile',    # blurb
        'Gscan2pdf::Scanner::Profile',               # package
        [qw/readable/]                               # flags
    ),
    Glib::ParamSpec->scalar(
        'visible-scan-options',                                  # name
        'Visible scan options',                                  # nick
        'Hash of scan options to show or hide from the user',    # blurb
        [qw/readable writable/]                                  # flags
    ),
    Glib::ParamSpec->float(
        'progress-pulse-step',                                   # name
        'Progress pulse step',                                   # nick
        'Pulse step of progress bar',                            # blurb
        0.0,                                                     # minimum
        1.0,                                                     # maximum
        0.1,                                                     # default_value
        [qw/readable writable/]                                  # flags
    ),
    Glib::ParamSpec->boolean(
        'allow-batch-flatbed',                                   # name
        'Allow batch scanning from flatbed',                     # nick
        'Allow batch scanning from flatbed',                     # blurb
        FALSE,                                                   # default_value
        [qw/readable writable/]                                  # flags
    ),
    Glib::ParamSpec->boolean(
        'adf-defaults-scan-all-pages',                           # name
        'Select # pages = all on selecting ADF',                 # nick
        'Select # pages = all on selecting ADF',                 # blurb
        TRUE,                                                    # default_value
        [qw/readable writable/]                                  # flags
    ),
    Glib::ParamSpec->int(
        'reload-recursion-limit',                                 # name
        'Reload recursion limit',                                 # nickname
        'More reloads than this are considered infinite loop',    # blurb
        0,                                                        # min
        $MAX_INCREMENT,                                           # max
        0,                                                        # default
        [qw/readable/]                                            # flags
    ),
    Glib::ParamSpec->int(
        'num-reloads',                                            # name
        'Number of reloads',                                      # nickname
        'To compare against reload-recursion-limit',              # blurb
        0,                                                        # min
        $MAX_INCREMENT,                                           # max
        0,                                                        # default
        [qw/readable/]                                            # flags
    ),
  ];

our $VERSION = '2.0.1';

my ( $d_sane, $logger );
my $tolerance             = 1;
my $SANE_NAME_SCAN_TL_X   = SANE_NAME_SCAN_TL_X;
my $SANE_NAME_SCAN_TL_Y   = SANE_NAME_SCAN_TL_Y;
my $SANE_NAME_SCAN_BR_X   = SANE_NAME_SCAN_BR_X;
my $SANE_NAME_SCAN_BR_Y   = SANE_NAME_SCAN_BR_Y;
my $SANE_NAME_PAGE_HEIGHT = SANE_NAME_PAGE_HEIGHT;
my $SANE_NAME_PAGE_WIDTH  = SANE_NAME_PAGE_WIDTH;

sub INIT_INSTANCE {
    my $self = shift;

    my $vbox = $self->get('vbox');

    $d_sane = Locale::gettext->domain('sane-backends');

    $self->_add_device_combobox($vbox);

    # Notebook to collate options
    $self->{notebook} = Gtk3::Notebook->new;
    $vbox->pack_start( $self->{notebook}, TRUE, TRUE, 0 );

    # Notebook page 1
    my $scwin = Gtk3::ScrolledWindow->new;
    $self->{notebook}
      ->append_page( $scwin, Gtk3::Label->new( __('Page Options') ) );
    $scwin->set_policy( 'automatic', 'automatic' );
    my $vbox1 = Gtk3::VBox->new;
    $self->{vbox} = $vbox1;
    $vbox1->set_border_width($BORDER_WIDTH);
    $scwin->add_with_viewport($vbox1);

    # Frame for # pages
    $self->{framen} = Gtk3::Frame->new( __('# Pages') );
    $vbox1->pack_start( $self->{framen}, FALSE, FALSE, 0 );
    my $vboxn        = Gtk3::VBox->new;
    my $border_width = $self->get('border_width');
    $vboxn->set_border_width($border_width);
    $self->{framen}->add($vboxn);

    # the first radio button has to set the group,
    # which is undef for the first button
    # All button
    my $bscanall =
      Gtk3::RadioButton->new_with_label_from_widget( undef, __('All') );
    $bscanall->set_tooltip_text( __('Scan all pages') );
    $vboxn->pack_start( $bscanall, TRUE, TRUE, 0 );
    $bscanall->signal_connect(
        clicked => sub {
            if ( $bscanall->get_active ) { $self->set( 'num-pages', 0 ) }
        }
    );

    # Entry button
    my $hboxn = Gtk3::HBox->new;
    $vboxn->pack_start( $hboxn, TRUE, TRUE, 0 );
    my $bscannum =
      Gtk3::RadioButton->new_with_label_from_widget( $bscanall, q{#:} );
    $bscannum->set_tooltip_text( __('Set number of pages to scan') );
    $hboxn->pack_start( $bscannum, FALSE, FALSE, 0 );

    # Number of pages
    my $spin_buttonn = Gtk3::SpinButton->new_with_range( 1, $MAX_PAGES, 1 );
    $spin_buttonn->set_tooltip_text( __('Set number of pages to scan') );
    $hboxn->pack_end( $spin_buttonn, FALSE, FALSE, 0 );
    $bscannum->signal_connect(
        clicked => sub {
            if ( $bscannum->get_active ) {
                $self->set( 'num-pages', $spin_buttonn->get_value );
            }
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
    $self->signal_connect(
        'changed-scan-option' => \&_changed_scan_option_callback,
        $bscannum
    );

    # Actively set a radio button to synchronise GUI and properties
    if ( $self->get('num-pages') > 0 ) {
        $bscannum->set_active(TRUE);
    }
    else {
        $bscanall->set_active(TRUE);
    }

    # vbox for duplex/simplex page numbering in order to be able to show/hide
    # them together.
    $self->{vboxx} = Gtk3::VBox->new;
    $vbox1->pack_start( $self->{vboxx}, FALSE, FALSE, 0 );

    # Toggle to switch between basic and extended modes
    $self->{checkx} =
      Gtk3::CheckButton->new( __('Extended page numbering') );
    $self->{vboxx}->pack_start( $self->{checkx}, FALSE, FALSE, 0 );

    # Frame for extended mode
    $self->{framex} = Gtk3::Frame->new( __('Page number') );
    $self->{vboxx}->pack_start( $self->{framex}, FALSE, FALSE, 0 );
    my $vboxx = Gtk3::VBox->new;
    $vboxx->set_border_width($border_width);
    $self->{framex}->add($vboxx);

    # SpinButton for starting page number
    my $hboxxs = Gtk3::HBox->new;
    $vboxx->pack_start( $hboxxs, FALSE, FALSE, 0 );
    my $labelxs = Gtk3::Label->new( __('Start') );
    $hboxxs->pack_start( $labelxs, FALSE, FALSE, 0 );
    my $spin_buttons = Gtk3::SpinButton->new_with_range( 1, $MAX_PAGES, 1 );
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
    my $hboxi = Gtk3::HBox->new;
    $vboxx->pack_start( $hboxi, FALSE, FALSE, 0 );
    my $labelxi = Gtk3::Label->new( __('Increment') );
    $hboxi->pack_start( $labelxi, FALSE, FALSE, 0 );
    my $spin_buttoni =
      Gtk3::SpinButton->new_with_range( -$MAX_INCREMENT, $MAX_INCREMENT, 1 );
    $spin_buttoni->set_value( $self->get('page-number-increment') );
    $hboxi->pack_end( $spin_buttoni, FALSE, FALSE, 0 );
    $spin_buttoni->signal_connect(
        'value-changed' => sub {
            my $value = $spin_buttoni->get_value;
            if ( $value == 0 ) { $value = -$self->get('page-number-increment') }
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
    $self->{frames} = Gtk3::Frame->new( __('Source document') );
    $self->{vboxx}->pack_start( $self->{frames}, FALSE, FALSE, 0 );
    my $vboxs = Gtk3::VBox->new;
    $vboxs->set_border_width($border_width);
    $self->{frames}->add($vboxs);

    # Single sided button
    $self->{buttons} = Gtk3::RadioButton->new_with_label_from_widget( undef,
        __('Single sided') );
    $self->{buttons}->set_tooltip_text( __('Source document is single-sided') );
    $vboxs->pack_start( $self->{buttons}, TRUE, TRUE, 0 );
    $self->{buttons}->signal_connect(
        clicked => sub {
            $spin_buttoni->set_value(1);
            $self->set( 'sided',
                $self->{buttons}->get_active == 1 ? 'single' : 'double' );
        }
    );

    # Double sided button
    $self->{buttond} =
      Gtk3::RadioButton->new_with_label_from_widget( $self->{buttons},
        __('Double sided') );
    $self->{buttond}->set_tooltip_text( __('Source document is double-sided') );
    $vboxs->pack_start( $self->{buttond}, FALSE, FALSE, 0 );

    # Facing/reverse page button
    my $hboxs = Gtk3::HBox->new;
    $vboxs->pack_start( $hboxs, TRUE, TRUE, 0 );
    my $labels = Gtk3::Label->new( __('Side to scan') );
    $hboxs->pack_start( $labels, FALSE, FALSE, 0 );

    $self->{combobs} = Gtk3::ComboBoxText->new;
    for ( ( __('Facing'), __('Reverse') ) ) {
        $self->{combobs}->append_text($_);
    }
    $self->{combobs}->signal_connect(
        changed => sub {
            $self->{buttond}->set_active(TRUE);    # Set the radiobutton active
            $self->set( 'side-to-scan',
                $self->{combobs}->get_active == 0 ? 'facing' : 'reverse' );
        }
    );
    $self->signal_connect(
        'changed-side-to-scan' => sub {
            my ( $widget, $value ) = @_;
            $self->set( 'page-number-increment',
                $value eq 'facing' ? $DOUBLE_INCREMENT : -$DOUBLE_INCREMENT );
        }
    );
    $self->{combobs}->set_tooltip_text(
        __('Sets which side of a double-sided document is scanned') );
    $self->{combobs}->set_active(0);

    # Have to do this here because setting the facing combobox switches it
    $self->{buttons}->set_active(TRUE);
    $hboxs->pack_end( $self->{combobs}, FALSE, FALSE, 0 );

    # Have to put the double-sided callback here to reference page side
    $self->{buttond}->signal_connect(
        clicked => sub {
            $spin_buttoni->set_value(
                  $self->{combobs}->get_active == 0
                ? $DOUBLE_INCREMENT
                : -$DOUBLE_INCREMENT
            );
        }
    );

    # Have to put the extended pagenumber checkbox here
    # to reference simple controls
    $self->{checkx}->signal_connect(
        toggled => \&_extended_pagenumber_checkbox_callback,
        [ $self, $spin_buttoni ]
    );

    # Scan profiles
    $self->{current_scan_options} = Gscan2pdf::Scanner::Profile->new;
    my $framesp = Gtk3::Frame->new( __('Scan profiles') );
    $vbox1->pack_start( $framesp, FALSE, FALSE, 0 );
    my $vboxsp = Gtk3::VBox->new;
    $vboxsp->set_border_width($border_width);
    $framesp->add($vboxsp);
    $self->{combobsp} = Gtk3::ComboBoxText->new;
    $self->{combobsp}->signal_connect(
        changed => sub {
            $self->{num_reloads} = 0;    # num-reloads is read-only
            $self->set( 'profile', $self->{combobsp}->get_active_text );
        }
    );
    $vboxsp->pack_start( $self->{combobsp}, FALSE, FALSE, 0 );
    my $hboxsp = Gtk3::HBox->new;
    $vboxsp->pack_end( $hboxsp, FALSE, FALSE, 0 );

    # Save button
    my $vbutton = Gtk3::Button->new_from_stock('gtk-save');
    $vbutton->signal_connect( clicked => \&_save_profile_callback, $self );
    $hboxsp->pack_start( $vbutton, TRUE, TRUE, 0 );

    # Delete button
    my $dbutton = Gtk3::Button->new_from_stock('gtk-delete');
    $dbutton->signal_connect(
        clicked => sub {
            $self->remove_profile( $self->{combobsp}->get_active_text );
        }
    );
    $hboxsp->pack_start( $dbutton, FALSE, FALSE, 0 );

    # HBox for buttons
    my $hboxb = Gtk3::HBox->new;
    $vbox->pack_end( $hboxb, FALSE, FALSE, 0 );

    # Scan button
    $self->{sbutton} = Gtk3::Button->new( __('Scan') );
    $hboxb->pack_start( $self->{sbutton}, TRUE, TRUE, 0 );
    $self->{sbutton}->signal_connect(
        clicked => sub {
            $self->signal_emit('clicked-scan-button');
            $self->scan;
        }
    );
    $self->{sbutton}->grab_focus;

    # Cancel button
    my $cbutton = Gtk3::Button->new_from_stock('gtk-close');
    $hboxb->pack_end( $cbutton, FALSE, FALSE, 0 );
    $cbutton->signal_connect( clicked => sub { $self->hide; } );

    # initialise stack of uuids - needed for cases where setting a profile
    # requires several reloads, and therefore reapplying the same profile
    # several times. Tested by t/06198_Dialog_Scan_Image_Sane.t
    $self->{setting_profile}              = [];
    $self->{setting_current_scan_options} = [];

    return $self;
}

sub _add_device_combobox {
    my ( $self, $vbox ) = @_;
    $self->{hboxd} = Gtk3::HBox->new;
    my $labeld = Gtk3::Label->new( __('Device') );
    $self->{hboxd}->pack_start( $labeld, FALSE, FALSE, 0 );
    $self->{combobd} = Gtk3::ComboBoxText->new;
    $self->{combobd}->append_text( __('Rescan for devices') );

    $self->{combobd_changed_signal} = $self->{combobd}->signal_connect(
        changed => sub {
            my $index       = $self->{combobd}->get_active;
            my $device_list = $self->get('device-list');
            if ( $index > $#{$device_list} ) {
                $self->{combobd}->hide;
                $labeld->hide;
                $self->set( 'device', undef )
                  ;    # to make sure that the device is reloaded
                $self->get_devices;
            }
            elsif ( $index > $NO_INDEX ) {
                $self->set( 'device', $device_list->[$index]{name} );
            }
        }
    );
    $self->signal_connect(
        'changed-device' => sub {
            my ( $self, $device ) = @_;
            my $device_list = $self->get('device-list');
            if ( defined $device and $device ne $EMPTY ) {
                for ( @{$device_list} ) {
                    if ( $_->{name} eq $device ) {
                        Gscan2pdf::Dialog::Scan::set_combobox_by_text(
                            $self->{combobd}, $_->{label} );
                        $self->scan_options($device);
                        return;
                    }
                }
            }
            else {
                $self->{combobd}->set_active($NO_INDEX);
            }
        }
    );
    $self->{combobd}
      ->set_tooltip_text( __('Sets the device to be used for the scan') );
    $self->{hboxd}->pack_end( $self->{combobd}, FALSE, FALSE, 0 );
    $vbox->pack_start( $self->{hboxd}, FALSE, FALSE, 0 );
    return;
}

sub _save_profile_callback {
    my ( $widget, $parent ) = @_;
    my $dialog = Gtk3::Dialog->new(
        __('Name of scan profile'), $parent,
        'destroy-with-parent',
        'gtk-save'   => 'ok',
        'gtk-cancel' => 'cancel'
    );
    my $hbox  = Gtk3::HBox->new;
    my $label = Gtk3::Label->new( __('Name of scan profile') );
    $hbox->pack_start( $label, FALSE, FALSE, 0 );
    my $entry = Gtk3::Entry->new;
    $entry->set_activates_default(TRUE);
    $hbox->pack_end( $entry, TRUE, TRUE, 0 );
    $dialog->vbox->add($hbox);
    $dialog->set_default_response('ok');
    $dialog->show_all;
    my $flag = TRUE;

    while ($flag) {
        if ( $dialog->run eq 'ok' ) {
            my $name = $entry->get_text;
            if ( $name !~ /^\s*$/xsm ) {
                if ( defined $parent->{profiles}{$name} ) {
                    my $warning = sprintf
                      __("Profile '%s' exists. Overwrite?"),
                      $name;
                    my $dialog2 = Gtk3::Dialog->new(
                        $warning, $dialog, 'destroy-with-parent',
                        'gtk-ok'     => 'ok',
                        'gtk-cancel' => 'cancel'
                    );
                    $label = Gtk3::Label->new($warning);
                    $dialog2->vbox->add($label);
                    $label->show;
                    if ( $dialog2->run eq 'ok' ) {
                        $parent->save_current_profile( $entry->get_text );
                        $flag = FALSE;
                    }
                    $dialog2->destroy;
                }
                else {
                    $parent->save_current_profile( $entry->get_text );
                    $flag = FALSE;
                }
            }
        }
        else {
            $flag = FALSE;
        }
    }
    $dialog->destroy;
    return;
}

sub SET_PROPERTY {
    my ( $self, $pspec, $newval ) = @_;
    my $name   = $pspec->get_name;
    my $oldval = $self->get($name);

    # Have to set logger separately as it has already been set in the subclassed
    # widget
    if ( $name eq 'logger' ) {
        $logger = $newval;
        $logger->debug('Set logger in Gscan2pdf::Dialog::Scan');
        $self->{$name} = $newval;
    }
    elsif (( defined $newval and defined $oldval and $newval ne $oldval )
        or ( defined $newval xor defined $oldval ) )
    {
        my $msg;
        if ( defined $logger ) {
            $msg =
                " setting $name from "
              . Gscan2pdf::Dialog::dump_or_stringify($oldval) . ' to '
              . Gscan2pdf::Dialog::dump_or_stringify($newval);
            $logger->debug("Started$msg");
        }
        my $callback = FALSE;
        given ($name) {
            when ('allow_batch_flatbed') {
                $self->_set_allow_batch_flatbed( $name, $newval );
            }
            when ('available_scan_options') {
                $self->_set_available_scan_options( $name, $newval );
            }
            when ('device') {
                $self->{$name} = $newval;
                $self->set_device($newval);
                $self->signal_emit( 'changed-device', $newval )
            }
            when ('device_list') {
                $self->{$name} = $newval;
                $self->set_device_list($newval);
                $self->signal_emit( 'changed-device-list', $newval )
            }
            when ('num_pages') {
                $self->_set_num_pages( $name, $newval );
            }
            when ('page_number_start') {
                $self->{$name} = $newval;
                $self->signal_emit( 'changed-page-number-start', $newval )
            }
            when ('page_number_increment') {
                $self->{$name} = $newval;
                $self->signal_emit( 'changed-page-number-increment', $newval )
            }
            when ('side_to_scan') {
                $self->{$name} = $newval;
                $self->signal_emit( 'changed-side-to-scan', $newval );
                $self->{combobs}->set_active( $newval eq 'facing' ? 0 : 1 );
            }
            when ('sided') {
                $self->{$name} = $newval;
                my $widget = $self->{buttons};
                if ( $newval eq 'double' ) {
                    $widget = $self->{buttond};
                }
                else {
                    # selecting single-sided also selects facing page.
                    $self->set( 'side-to-scan', 'facing' );
                }
                $widget->set_active(TRUE);
            }
            when ('paper') {
                if ( defined $newval ) {
                    for ( @{ $self->{ignored_paper_formats} } ) {
                        if ( $_ eq $newval ) {
                            if ( defined $logger ) {
                                $logger->info(
                                    "Ignoring unsupported paper $newval");
                                $logger->debug("Finished$msg");
                            }
                            return;
                        }
                    }
                }
                $callback = TRUE;
                my $signal;
                $signal = $self->signal_connect(
                    'changed-paper' => sub {
                        $self->signal_handler_disconnect($signal);
                        my $paper = defined $newval ? $newval : __('Manual');
                        set_combobox_by_text( $self->{combobp}, $paper );
                        if ( defined $logger ) {
                            $logger->debug("Finished$msg");
                        }
                    }
                );
                $self->set_paper($newval);
                $self->{current_scan_options}
                  ->add_frontend_option( $name, $newval );
            }
            when ('paper_formats') {
                $self->{$name} = $newval;
                $self->set_paper_formats($newval);
                $self->signal_emit( 'changed-paper-formats', $newval )
            }
            when ('profile') {
                $callback = TRUE;
                my $signal;
                $signal = $self->signal_connect(
                    'changed-profile' => sub {
                        $self->signal_handler_disconnect($signal);
                        set_combobox_by_text( $self->{combobsp}, $newval );
                        if ( defined $logger ) {
                            $logger->debug("Finished$msg");
                        }
                    }
                );
                $self->set_profile($newval);
            }
            when ('visible_scan_options') {
                $self->{$name} = $newval;
                $self->signal_emit( 'changed-option-visibility', $newval );
            }
            default {
                $self->SUPER::SET_PROPERTY( $pspec, $newval );
            }
        }
        if ( defined $logger and not $callback ) {
            $logger->debug("Finished$msg");
        }
    }
    return;
}

sub _flatbed_or_duplex_callback {
    my ($self) = @_;
    my $options = $self->get('available-scan-options');
    if ( defined $options ) {
        if ( $self->_flatbed_selected($options) or $options->can_duplex ) {
            $self->{vboxx}->hide;
        }
        else {
            $self->{vboxx}->show;
        }
    }
    return;
}

sub _changed_scan_option_callback {
    my ( $self, $name, $value, $uuid, $bscannum ) = @_;
    my $options = $self->get('available-scan-options');
    if (    defined $options
        and defined $options->{source}{name}
        and $name eq $options->{source}{name} )
    {
        if ( $self->get('allow-batch-flatbed')
            or not $self->_flatbed_selected($options) )
        {
            $self->{framen}->set_sensitive(TRUE);
        }
        else {
            $bscannum->set_active(TRUE);
            $self->set( 'num-pages', 1 );
            $self->{framen}->set_sensitive(FALSE);
        }

        if (    $self->get('adf-defaults-scan-all-pages')
            and $value =~ /(ADF|Automatic[ ]Document[ ]Feeder)/xsmi )
        {
            $self->set( 'num-pages', 0 );
        }
    }
    $self->_flatbed_or_duplex_callback;
    return;
}

sub _set_allow_batch_flatbed {
    my ( $self, $name, $newval ) = @_;
    $self->{$name} = $newval;
    if ($newval) {
        $self->{framen}->set_sensitive(TRUE);
    }
    else {
        my $options = $self->get('available-scan-options');
        if ( $self->_flatbed_selected($options) ) {
            $self->{framen}->set_sensitive(FALSE);

            # emits changed-num-pages signal, allowing us to test
            # for $self->{framen}->set_sensitive(FALSE)
            $self->set( 'num-pages', 1 );
        }
    }
    return;
}

sub _flatbed_selected {
    my ( $self, $options ) = @_;
    return (
              defined $options
          and defined $options->{source}
          and ( defined $options->{source}{val}
            and $options->{source}{val} =~ /flatbed/xsmi )
          or (  $#{ $options->{source}{constraint} } == 0
            and $options->{source}{constraint}[0] =~ /flatbed/xsmi )
    );
}

sub _set_available_scan_options {
    my ( $self, $name, $newval ) = @_;
    $self->{$name} = $newval;
    if ( not $self->get('allow-batch-flatbed')
        and $self->_flatbed_selected($newval) )
    {
        if ( $self->get('num-pages') != 1 ) { $self->set( 'num-pages', 1 ) }
        $self->{framen}->set_sensitive(FALSE);
    }
    else {
        $self->{framen}->set_sensitive(TRUE);
    }

    $self->_flatbed_or_duplex_callback;

    # reload-recursion-limit is read-only
    # Triangular number n + n-1 + n-2 + ... + 1 = n*(n+1)/2
    my $n = $newval->num_options;
    $self->{reload_recursion_limit} = $n * ( $n + 1 ) / 2;

    $self->signal_emit('reloaded-scan-options');
    return;
}

sub _set_num_pages {
    my ( $self, $name, $newval ) = @_;
    my $options = $self->get('available-scan-options');
    if (
           $newval == 1
        or $self->get('allow-batch-flatbed')
        or (    defined $options
            and defined $options->{source}{val}
            and not $self->_flatbed_selected($options) )
      )
    {
        $self->{$name} = $newval;
        $self->{current_scan_options}->add_frontend_option( $name, $newval );
        $self->signal_emit( 'changed-num-pages', $newval );
    }
    return;
}

sub show {
    my $self = shift;
    $self->signal_chain_from_overridden;
    $self->{framex}->hide;
    $self->_flatbed_or_duplex_callback;
    if (    defined $self->{combobp}
        and defined $self->{combobp}->get_active_text
        and $self->{combobp}->get_active_text ne __('Manual') )
    {
        $self->hide_geometry( $self->get('available-scan-options') );
    }
    return;
}

sub set_device {
    my ( $self, $device ) = @_;
    if ( defined $device and $device ne $EMPTY ) {
        my $o;
        my $device_list = $self->get('device_list');
        if ( defined $device_list ) {
            for ( 0 .. $#{$device_list} ) {
                if ( $device eq $device_list->[$_]{name} ) { $o = $_ }
            }

            # Set the device dependent options after the number of pages
            #  to scan so that the source button callback can ghost the
            #  all button.
            # This then fires the callback, updating the options,
            #  so no need to do it further down.
            if ( defined $o ) {
                $self->{combobd}->set_active($o);
            }
            else {
                $self->signal_emit( 'process-error', 'open_device',
                    sprintf __('Error: unknown device: %s'), $device );
            }
        }
    }
    return;
}

sub set_device_list {
    my ( $self, $device_list ) = @_;

    # Note any duplicate device names and delete if necessary
    my %seen;
    my $i = 0;
    while ( $i < @{$device_list} ) {
        $seen{ $device_list->[$i]{name} }++;
        if ( $seen{ $device_list->[$i]{name} } > 1 ) {
            splice @{$device_list}, $i, 1;
        }
        else {
            $i++;
        }
    }

    # Note any duplicate model names and add the device if necessary
    undef %seen;
    for ( @{$device_list} ) {
        if ( not defined $_->{model} ) { $_->{model} = $_->{name} }
        $seen{ $_->{model} }++;
    }
    for ( @{$device_list} ) {
        if ( defined $_->{vendor} ) {
            $_->{label} = "$_->{vendor} $_->{model}";
        }
        else {
            $_->{label} = $_->{model};
        }
        if ( $seen{ $_->{model} } > 1 ) { $_->{label} .= " on $_->{name}" }
    }

    $self->{combobd}->signal_handler_block( $self->{combobd_changed_signal} );

    # Remove all entries apart from rescan
    my $num_rows = get_combobox_num_rows( $self->{combobd} );
    while ( $num_rows-- > 1 ) {
        $self->{combobd}->remove(0);
    }

    # read the model names into the combobox
    for ( 0 .. $#{$device_list} ) {
        $self->{combobd}->insert_text( $_, $device_list->[$_]{label} );
    }

    $self->{combobd}->signal_handler_unblock( $self->{combobd_changed_signal} );
    return;
}

sub pack_widget {
    my ( $self, $widget, $data ) = @_;
    my ( $options, $opt, $hbox, $hboxp ) = @{$data};
    if ( defined $widget ) {

        # Add label for units
        if ( $opt->{unit} != SANE_UNIT_NONE ) {
            my $text;
            given ( $opt->{unit} ) {
                when (SANE_UNIT_PIXEL) {
                    $text = $d_sane->get('pel')
                }
                when (SANE_UNIT_BIT) {
                    $text = $d_sane->get('bit')
                }
                when (SANE_UNIT_MM) {
                    $text = $d_sane->get('mm')
                }
                when (SANE_UNIT_DPI) {
                    $text = $d_sane->get('dpi')
                }
                when (SANE_UNIT_PERCENT) {
                    $text = $d_sane->get(q{%})
                }
                when (SANE_UNIT_MICROSECOND) {
                    $text = $d_sane->get('us')
                }
            }
            my $label = Gtk3::Label->new($text);
            $hbox->pack_end( $label, FALSE, FALSE, 0 );
        }

        $self->{option_widgets}{ $opt->{name} } = $widget;
        if ( $opt->{type} == SANE_TYPE_BUTTON or $opt->{max_values} > 1 ) {
            $hbox->pack_end( $widget, TRUE, TRUE, 0 );
        }
        else {
            $hbox->pack_end( $widget, FALSE, FALSE, 0 );
        }
        $widget->set_tooltip_text( $d_sane->get( $opt->{desc} ) );

        # Look-up to hide/show the box if necessary
        if ( $self->_geometry_option($opt) ) {
            $self->{geometry_boxes}{ $opt->{name} } = $hbox;
        }

        $self->create_paper_widget( $options, $hboxp );
    }
    else {
        $logger->warn("Unknown type $opt->{type}");
    }
    return;
}

# Return true if we have a valid geometry option

sub _geometry_option {
    my ( $self, $opt ) = @_;
    return (
        ( $opt->{type} == SANE_TYPE_FIXED or $opt->{type} == SANE_TYPE_INT )
          and
          ( $opt->{unit} == SANE_UNIT_MM or $opt->{unit} == SANE_UNIT_PIXEL )
          and ( $opt->{name} =~
/^(?:$SANE_NAME_SCAN_TL_X|$SANE_NAME_SCAN_TL_Y|$SANE_NAME_SCAN_BR_X|$SANE_NAME_SCAN_BR_Y|$SANE_NAME_PAGE_HEIGHT|$SANE_NAME_PAGE_WIDTH)$/xms
          )
    );
}

sub create_paper_widget {
    my ( $self, $options, $hboxp ) = @_;

    # Only define the paper size once the rest of the geometry widgets
    # have been created
    if (
            defined( $self->{geometry_boxes}{$SANE_NAME_SCAN_BR_X} )
        and defined( $self->{geometry_boxes}{$SANE_NAME_SCAN_BR_Y} )
        and defined( $self->{geometry_boxes}{$SANE_NAME_SCAN_TL_X} )
        and defined( $self->{geometry_boxes}{$SANE_NAME_SCAN_TL_Y} )
        and ( not defined $options->by_name(SANE_NAME_PAGE_HEIGHT)
            or defined( $self->{geometry_boxes}{$SANE_NAME_PAGE_HEIGHT} ) )
        and ( not defined $options->by_name(SANE_NAME_PAGE_WIDTH)
            or defined( $self->{geometry_boxes}{$SANE_NAME_PAGE_WIDTH} ) )
        and not defined( $self->{combobp} )
      )
    {

        # Paper list
        my $label = Gtk3::Label->new( __('Paper size') );
        $hboxp->pack_start( $label, FALSE, FALSE, 0 );

        $self->{combobp} = Gtk3::ComboBoxText->new;
        $self->{combobp}->append_text( __('Manual') );
        $self->{combobp}->append_text( __('Edit') );
        $self->{combobp}
          ->set_tooltip_text( __('Selects or edits the paper size') );
        $hboxp->pack_end( $self->{combobp}, FALSE, FALSE, 0 );
        $self->{combobp}->set_active(0);
        $self->{combobp}->signal_connect(
            changed => sub {
                if ( not defined $self->{combobp}->get_active_text ) { return }

                if ( $self->{combobp}->get_active_text eq __('Edit') ) {
                    $self->edit_paper;
                }
                elsif ( $self->{combobp}->get_active_text eq __('Manual') ) {
                    for (
                        ( SANE_NAME_SCAN_TL_X, SANE_NAME_SCAN_TL_Y,
                            SANE_NAME_SCAN_BR_X,   SANE_NAME_SCAN_BR_Y,
                            SANE_NAME_PAGE_HEIGHT, SANE_NAME_PAGE_WIDTH
                        )
                      )
                    {
                        if ( defined $self->{geometry_boxes}{$_} ) {
                            $self->{geometry_boxes}{$_}->show_all;
                        }
                    }
                    $self->set( 'paper', undef );
                }
                else {
                    my $paper = $self->{combobp}->get_active_text;
                    $self->set( 'paper', $paper );
                }
            }
        );

        # If the geometry is changed, unset the paper size
        for (
            ( SANE_NAME_SCAN_TL_X, SANE_NAME_SCAN_TL_Y,
                SANE_NAME_SCAN_BR_X,   SANE_NAME_SCAN_BR_Y,
                SANE_NAME_PAGE_HEIGHT, SANE_NAME_PAGE_WIDTH
            )
          )
        {
            if ( defined $options->by_name($_) ) {
                my $widget = $self->{option_widgets}{$_};
                $widget->signal_connect(
                    changed => sub {
                        if ( defined $self->get('paper') ) {
                            $self->set( 'paper', undef );
                        }
                    }
                );
            }
        }
    }
    return;
}

sub hide_geometry {
    my ( $self, $options ) = @_;
    for (
        ( SANE_NAME_SCAN_TL_X, SANE_NAME_SCAN_TL_Y,
            SANE_NAME_SCAN_BR_X,   SANE_NAME_SCAN_BR_Y,
            SANE_NAME_PAGE_HEIGHT, SANE_NAME_PAGE_WIDTH
        )
      )
    {
        if ( defined $self->{geometry_boxes}{$_} ) {
            $self->{geometry_boxes}{$_}->hide;
        }
    }
    return;
}

sub get_paper_by_geometry {
    my ($self) = @_;
    my $formats = $self->get('paper-formats');
    if ( not defined $formats ) { return }
    my $options = $self->get('available-scan-options');
    my %current = (
        l => $options->by_name(SANE_NAME_SCAN_TL_X)->{val},
        t => $options->by_name(SANE_NAME_SCAN_TL_Y)->{val},
    );
    $current{x} = $current{l} + $options->by_name(SANE_NAME_SCAN_BR_X)->{val};
    $current{y} = $current{t} + $options->by_name(SANE_NAME_SCAN_BR_Y)->{val};
    for my $paper ( keys %{$formats} ) {
        my $match = TRUE;
        for (qw(l t x y)) {
            if ( $formats->{$paper}{$_} != $current{$_} ) {
                $match = FALSE;
                last;
            }
        }
        if ($match) { return $paper }
    }
    return;
}

# If setting an option triggers a reload, the widgets must be updated to reflect
# the new options

sub update_options {
    my ( $self, $new_options ) = @_;

    my $loops = $self->get('num-reloads');
    $self->{num_reloads} = ++$loops;    # num-reloads is read-only
    my $limit = $self->get('reload-recursion-limit');
    if ( $self->get('num-reloads') > $limit ) {
        $logger->error("reload-recursion-limit ($limit) exceeded.");
        $self->signal_emit(
            'process-error',
            'update_options',
            sprintf __(
'Reload recursion limit (%d) exceeded. Please file a bug, attaching a log file reproducing the problem.'
            ),
            $limit
        );
        return;
    }

    # Clone the current scan options in case they are changed by the reload,
    # so that we can reapply it afterwards to ensure the same values are still
    # set.
    my $current_scan_options = dclone( $self->{current_scan_options} );

    # Loop through the cloned profile, and remove those options that have
    # correct values in the reload
    my $num = $current_scan_options->num_backend_options;
    my $i   = 0;
    while ( $i < $num ) {
        my ( $name, $val ) =
          $current_scan_options->get_backend_option_by_index($i);
        my $opt = $new_options->by_name($name);
        if ( not defined $val
            or Gscan2pdf::Scanner::Options::within_tolerance( $opt, $val ) )
        {
            $logger->info(
                "No need to update option '$name': already within tolerance.");
            $current_scan_options->remove_backend_option_by_name($name);
            --$num;
        }
        else {
            $logger->info(
"Setting option '$name' to '$val' (again): '$opt->{val}' out of tolerance."
            );
            ++$i;
        }
    }

    # walk the widget tree and update them from the hash
    $logger->debug( 'Sane->get_option_descriptor returned: ',
        Dumper($new_options) );

    my $num_dev_options = $new_options->num_options;
    my $options         = $self->get('available-scan-options');
    for ( 1 .. $num_dev_options - 1 ) {
        if (
            $self->_update_option(
                $options->by_index($_),
                $new_options->by_index($_)
            )
          )
        {
            return;
        }
    }

    # This fires the reloaded-scan-options signal,
    # so don't set this until we have finished
    $self->set( 'available-scan-options', $new_options );

    # Reapply current options to ensure the same values are still set.
    $self->set_current_scan_options($current_scan_options);

    # In case the geometry values have changed,
    # update the available paper formats
    $self->set_paper_formats( $self->{paper_formats} );
    return;
}

sub _update_option {
    my ( $self, $opt, $new_opt ) = @_;

    # could be undefined for !($new_opt->{cap} & SANE_CAP_SOFT_DETECT)
    # or where $opt->{name} is not defined
    # e.g. $opt->{type} == SANE_TYPE_GROUP
    if (   $opt->{type} == SANE_TYPE_GROUP
        or not defined $opt->{name}
        or not defined $self->{option_widgets}{ $opt->{name} } )
    {
        return;
    }
    my $widget = $self->{option_widgets}{ $opt->{name} };

    if ( $new_opt->{name} ne $opt->{name} ) {
        $logger->error(
            'Error updating options: reloaded options are numbered differently'
        );
        return TRUE;
    }
    if ( $opt->{type} != $new_opt->{type} ) {
        $logger->error(
            'Error updating options: reloaded options have different types');
        return TRUE;
    }

    # Block the signal handler for the widget to prevent infinite
    # loops of the widget updating the option, updating the widget, etc.
    $widget->signal_handler_block( $widget->{signal} );
    $opt = $new_opt;
    my $value = $opt->{val};

    # HBox for option
    my $hbox = $widget->get_parent;
    $hbox->set_sensitive( ( not $opt->{cap} & SANE_CAP_INACTIVE )
          and $opt->{cap} & SANE_CAP_SOFT_SELECT );

    if ( $opt->{max_values} < 2 ) {

        # CheckButton
        if ( $opt->{type} == SANE_TYPE_BOOL ) {
            if ( $self->value_for_active_option( $value, $opt ) ) {
                $widget->set_active($value);
            }
        }
        else {
            given ( $opt->{constraint_type} ) {

                # SpinButton
                when (SANE_CONSTRAINT_RANGE) {
                    my ( $step, $page ) = $widget->get_increments;
                    $step = 1;
                    if ( $opt->{constraint}{quant} ) {
                        $step = $opt->{constraint}{quant};
                    }
                    $widget->set_range( $opt->{constraint}{min},
                        $opt->{constraint}{max} );
                    $widget->set_increments( $step, $page );
                    if ( $self->value_for_active_option( $value, $opt ) ) {
                        $widget->set_value($value);
                    }
                }

                # ComboBox
                when (
                    [ SANE_CONSTRAINT_STRING_LIST, SANE_CONSTRAINT_WORD_LIST ] )
                {
                    $widget->get_model->clear;
                    my $index = 0;
                    for ( 0 .. $#{ $opt->{constraint} } ) {
                        $widget->append_text(
                            $d_sane->get( $opt->{constraint}[$_] ) );
                        if ( defined $value
                            and $opt->{constraint}[$_] eq $value )
                        {
                            $index = $_;
                        }
                    }
                    if ( defined $index ) { $widget->set_active($index) }
                }

                # Entry
                when (SANE_CONSTRAINT_NONE) {
                    if ( $self->value_for_active_option( $value, $opt ) ) {
                        $widget->set_text($value);
                    }
                }
            }
        }
    }
    $widget->signal_handler_unblock( $widget->{signal} );
    return;
}

# Add paper size to combobox if scanner large enough

sub set_paper_formats {
    my ( $self, $formats ) = @_;
    my $combobp = $self->{combobp};

    if ( defined $combobp ) {

        # Remove all formats, leaving Manual and Edit
        my $n = get_combobox_num_rows($combobp);
        while ( $n-- > 2 ) { $combobp->remove(0) }

        $self->{ignored_paper_formats} = ();
        my $options = $self->get('available-scan-options');
        for ( keys %{$formats} ) {
            if ( $options->supports_paper( $formats->{$_}, $tolerance ) ) {
                $logger->debug("Options support paper size '$_'.");
                $combobp->prepend_text($_);
            }
            else {
                $logger->debug("Options do not support paper size '$_'.");
                push @{ $self->{ignored_paper_formats} }, $_;
            }
        }

        # Set the combobox back from Edit to the previous value
        my $paper = $self->get('paper');
        if ( not defined $paper ) { $paper = __('Manual') }
        set_combobox_by_text( $combobp, $paper );
    }
    return;
}

# Treat a paper size as a profile, so build up the required profile of geometry
# settings and apply it
sub set_paper {
    my ( $self, $paper ) = @_;
    if ( not defined $paper ) {
        $self->{paper} = $paper;
        $self->signal_emit( 'changed-paper', $paper );
        return;
    }
    for ( @{ $self->{ignored_paper_formats} } ) {
        if ( $_ eq $paper ) {
            if ( defined $logger ) {
                $logger->info("Ignoring unsupported paper $paper");
            }
            return;
        }
    }
    my $formats       = $self->get('paper-formats');
    my $options       = $self->get('available-scan-options');
    my $paper_profile = Gscan2pdf::Scanner::Profile->new;
    if ( defined( $options->by_name(SANE_NAME_PAGE_HEIGHT) )
        and not $options->by_name(SANE_NAME_PAGE_HEIGHT)->{cap} &
        SANE_CAP_INACTIVE
        and defined( $options->by_name(SANE_NAME_PAGE_WIDTH) )
        and not $options->by_name(SANE_NAME_PAGE_WIDTH)->{cap} &
        SANE_CAP_INACTIVE )
    {
        $paper_profile->add_backend_option( SANE_NAME_PAGE_HEIGHT,
            $formats->{$paper}{y} + $formats->{$paper}{t},
            $options->by_name(SANE_NAME_PAGE_HEIGHT)->{val}
        );
        $paper_profile->add_backend_option( SANE_NAME_PAGE_WIDTH,
            $formats->{$paper}{x} + $formats->{$paper}{l},
            $options->by_name(SANE_NAME_PAGE_WIDTH)->{val}
        );
    }
    $paper_profile->add_backend_option( SANE_NAME_SCAN_TL_X,
        $formats->{$paper}{l},
        $options->by_name(SANE_NAME_SCAN_TL_X)->{val}
    );
    $paper_profile->add_backend_option( SANE_NAME_SCAN_TL_Y,
        $formats->{$paper}{t},
        $options->by_name(SANE_NAME_SCAN_TL_Y)->{val}
    );
    $paper_profile->add_backend_option( SANE_NAME_SCAN_BR_X,
        $formats->{$paper}{x} + $formats->{$paper}{l},
        $options->by_name(SANE_NAME_SCAN_BR_X)->{val}
    );
    $paper_profile->add_backend_option( SANE_NAME_SCAN_BR_Y,
        $formats->{$paper}{y} + $formats->{$paper}{t},
        $options->by_name(SANE_NAME_SCAN_BR_Y)->{val}
    );

    if ( not $paper_profile->num_backend_options ) {
        $self->hide_geometry($options);
        $self->{paper} = $paper;
        $self->signal_emit( 'changed-paper', $paper );
        return;
    }

    my $signal;
    $signal = $self->signal_connect(
        'changed-current-scan-options' => sub {
            $self->signal_handler_disconnect($signal);
            $self->hide_geometry($options);
            $self->{paper} = $paper;
            $self->set( 'profile', undef );
            $self->signal_emit( 'changed-paper', $paper );
        }
    );

    # Don't trigger the changed-paper signal
    # until we have finished setting the profile
    $self->set_current_scan_options($paper_profile);
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
        title           => __('Edit paper size'),
        border_width    => $self->get('border-width'),
    );
    my $vbox = $window->get('vbox');

    # Buttons for SimpleList
    my $hboxl = Gtk3::HBox->new;
    $vbox->pack_start( $hboxl, FALSE, FALSE, 0 );
    my $vboxb = Gtk3::VBox->new;
    $hboxl->pack_start( $vboxb, FALSE, FALSE, 0 );
    my $dbutton = Gtk3::Button->new_from_stock('gtk-add');
    $vboxb->pack_start( $dbutton, TRUE, FALSE, 0 );
    my $rbutton = Gtk3::Button->new_from_stock('gtk-remove');
    $vboxb->pack_end( $rbutton, TRUE, FALSE, 0 );

    # Set up a SimpleList
    my $slist = Gtk3::SimpleList->new(
        __('Name')   => 'text',
        __('Width')  => 'int',
        __('Height') => 'int',
        __('Left')   => 'int',
        __('Top')    => 'int',
        __('Units')  => 'text',
    );
    for ( keys %{$formats} ) {
        push @{ $slist->{data} },
          [
            $_,                $formats->{$_}{x}, $formats->{$_}{y},
            $formats->{$_}{l}, $formats->{$_}{t}, 'mm',
          ];
    }

    # Set everything to be editable except the units
    my @columns = $slist->get_columns;
    for ( 0 .. $#columns - 1 ) {
        $slist->set_column_editable( $_, TRUE );
    }
    $slist->get_column(0)->set_sort_column_id(0);

    # Add button callback
    $dbutton->signal_connect(
        clicked => sub {
            my @rows = $slist->get_selected_indices;
            if ( not @rows ) { $rows[0] = 0 }
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
            my @line = ("$name ($version)");
            @columns = $slist->get_columns;
            for ( 1 .. $#columns ) {
                push @line, $slist->{data}[ $rows[0] ][$_];
            }
            splice @{ $slist->{data} }, $rows[0] + 1, 0, \@line;
        }
    );

    # Remove button callback
    $rbutton->signal_connect(
        clicked => sub {
            my @rows = $slist->get_selected_indices;
            if ( $#rows == $#{ $slist->{data} } ) {
                main::show_message_dialog(
                    parent  => $window,
                    type    => 'error',
                    buttons => 'close',
                    text    => __('Cannot delete all paper sizes')
                );
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
            for ( 0 .. $#{ $slist->{data} } ) {
                if (    $_ != $path->to_string
                    and $slist->{data}[ $path->to_string ][0] eq
                    $slist->{data}[$_][0] )
                {
                    my $name    = $slist->{data}[ $path->to_string ][0];
                    my $version = 2;
                    if (
                        $name =~ qr{
                     (.*) # name
                     [ ][(] # space, opening bracket
                     (\d+) # version
                     [)] # closing bracket
                   }xsm
                      )
                    {
                        $name    = $1;
                        $version = $2 + 1;
                    }
                    $slist->{data}[ $path->to_string ][0] =
                      "$name ($version)";
                    return;
                }
            }
        }
    );
    $hboxl->pack_end( $slist, FALSE, FALSE, 0 );

    # Buttons
    my $hboxb = Gtk3::HBox->new;
    $vbox->pack_start( $hboxb, FALSE, FALSE, 0 );
    my $abutton = Gtk3::Button->new_from_stock('gtk-apply');
    $abutton->signal_connect(
        clicked => sub {
            my %formats;
            for my $i ( 0 .. $#{ $slist->{data} } ) {
                my $j = 0;
                for (qw( x y l t)) {
                    $formats{ $slist->{data}[$i][0] }{$_} =
                      $slist->{data}[$i][ ++$j ];
                }
            }

            # Add new definitions
            $self->set( 'paper-formats', \%formats );
            if ( $self->{ignored_paper_formats}
                and @{ $self->{ignored_paper_formats} } )
            {
                main::show_message_dialog(
                    parent  => $window,
                    type    => 'warning',
                    buttons => 'close',
                    text    => __(
'The following paper sizes are too big to be scanned by the selected device:'
                      )
                      . q{ }
                      . join ', ',
                    @{ $self->{ignored_paper_formats} }
                );
            }

            $window->destroy;
        }
    );
    $hboxb->pack_start( $abutton, TRUE, FALSE, 0 );
    my $cbutton = Gtk3::Button->new_from_stock('gtk-cancel');
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

# keeping this as a separate sub allows us to test it
sub save_current_profile {
    my ( $self, $name ) = @_;
    $self->add_profile( $name, $self->{current_scan_options} );
    $self->{combobsp}
      ->set_active( get_combobox_num_rows( $self->{combobsp} ) - 1 );
    return;
}

sub add_profile {
    my ( $self, $name, $profile ) = @_;
    if ( not defined $name ) {
        $logger->error('Cannot add profile with no name');
        return;
    }
    elsif ( not defined $profile ) {
        $logger->error('Cannot add undefined profile');
        return;
    }
    elsif ( ref($profile) ne 'Gscan2pdf::Scanner::Profile' ) {
        $logger->error(
            ref($profile) . ' is not a Gscan2pdf::Scanner::Profile object' );
        return;
    }

    # if we don't clone the profile,
    # we get strange action-at-a-distance problems
    $self->{profiles}{$name} = dclone($profile);

    _combobox_remove_item_by_text( $self->{combobsp}, $name );

    $self->{combobsp}->append_text($name);
    $logger->debug( "Saved profile '$name':",
        Dumper( $self->{profiles}{$name}->get_data ) );
    $self->signal_emit( 'added-profile', $name, $self->{profiles}{$name} );
    return;
}

sub _combobox_remove_item_by_text {
    my ( $combobox, $text ) = @_;
    if ( defined $text ) {
        my $i = get_combobox_by_text( $combobox, $text );
        if ( $i > $NO_INDEX ) {
            if ( $combobox->get_active == $i ) {
                $combobox->set_active($NO_INDEX);
            }
            $combobox->remove($i);
        }
    }
    return;
}

sub set_profile {
    my ( $self, $name ) = @_;
    if ( defined $name and $name ne $EMPTY ) {

        # Only emit the changed-profile signal when the GUI has caught up
        my $signal;
        $signal = $self->signal_connect(
            'changed-current-scan-options' => sub {
                my ( undef, undef, $uuid_found ) = @_;

                my $uuid = $self->{setting_profile}->[0];

                # there seems to be a race condition in t/0621_Dialog_Scan_CLI.t
                # where the uuid set below is not set in time to be tested in
                # this if.
                if ( $uuid eq $uuid_found ) {
                    $self->signal_handler_disconnect($signal);
                    $self->{setting_profile} = [];

                    # set property before emitting signal to ensure callbacks
                    # receive correct value
                    $self->{profile} = $name;
                    $self->signal_emit( 'changed-profile', $name );
                }
            }
        );

        # Add UUID to the stack and therefore don't unset the profile name
        push @{ $self->{setting_profile} }, $self->{profiles}{$name}->{uuid};
        $self->set_current_scan_options( $self->{profiles}{$name} );
    }

    # no need to wait - nothing to do
    else {
        # set property before emitting signal to ensure callbacks
        # receive correct value
        $self->{profile} = $name;
        $self->signal_emit( 'changed-profile', $name );
    }
    return;
}

# Remove the profile. If it is active, deselect it first.

sub remove_profile {
    my ( $self, $name ) = @_;
    if ( defined $name and defined $self->{profiles}{$name} ) {
        _combobox_remove_item_by_text( $self->{combobsp}, $name );
        $self->signal_emit( 'removed-profile', $name );
        delete $self->{profiles}{$name};
    }
    return;
}

sub get_combobox_num_rows {
    my ($combobox) = @_;
    my $i = 0;
    if ( defined $combobox and defined( $combobox->get_model ) ) {
        $combobox->get_model->foreach(
            sub {
                ++$i;
                return FALSE;    # continue the foreach()
            }
        );
    }
    return $i;
}

sub get_combobox_by_text {
    my ( $combobox, $text ) = @_;
    my $o = $NO_INDEX;
    my $i = 0;
    if (    defined $combobox
        and defined( $combobox->get_model )
        and defined $text )
    {
        $combobox->get_model->foreach(
            sub {
                my ( $model, $path, $iter ) = @_;
                if ( $model->get( $iter, 0 ) eq $text ) {
                    $o = $i;
                    return TRUE;    # found - stop the foreach()
                }
                else {
                    ++$i;
                    return FALSE;    # not found - continue the foreach()
                }
            }
        );
    }
    return $o;
}

sub set_combobox_by_text {
    my ( $combobox, $text ) = @_;
    if ( defined $combobox ) {
        my $index = get_combobox_by_text( $combobox, $text );
        if ( $index > $NO_INDEX or not defined $text ) {
            $combobox->set_active($index);
            return TRUE;
        }
    }
    return;
}

sub _extended_pagenumber_checkbox_callback {
    my ( $widget, $data )         = @_;
    my ( $dialog, $spin_buttoni ) = @{$data};
    if ( $widget->get_active ) {
        $dialog->{frames}->hide;
        $dialog->{framex}->show_all;
    }
    else {
        if ( $spin_buttoni->get_value == 1 ) {
            $dialog->{buttons}->set_active(TRUE);
        }
        elsif ( $spin_buttoni->get_value > 0 ) {
            $dialog->{buttond}->set_active(TRUE);
            $dialog->{combobs}->set_active(FALSE);
        }
        else {
            $dialog->{buttond}->set_active(TRUE);
            $dialog->{combobs}->set_active(TRUE);
        }
        $dialog->{frames}->show_all;
        $dialog->{framex}->hide;
    }
    return;
}

sub multiple_values_button_callback {
    my ( $widget, $data ) = @_;
    my ( $dialog, $opt )  = @{$data};
    if (   $opt->{type} == SANE_TYPE_FIXED
        or $opt->{type} == SANE_TYPE_INT )
    {
        if ( $opt->{constraint_type} == SANE_CONSTRAINT_NONE ) {
            main::show_message_dialog(
                parent  => $dialog,
                type    => 'info',
                buttons => 'close',
                text    => __(
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
            parent  => $dialog,
            type    => 'info',
            buttons => 'close',
            text    => __(
'Multiple non-numerical values are not currently supported. Please file a bug.'
            )
        );
    }
    return;
}

sub value_for_active_option {
    my ( $self, $value, $opt ) = @_;
    return ( defined $value and not $opt->{cap} & SANE_CAP_INACTIVE );
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
    $canvas->set_size_request( $CANVAS_SIZE, $CANVAS_SIZE );
    $canvas->{border} = $CANVAS_BORDER;
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
            my $fleur = Gtk3::Gdk::Cursor->new('fleur');
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
            if ( $event->keyval == Gtk3::Gdk::KEY_Delete
                and defined $widget->{selected} )
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
        @{ $opt->{constraint} } =
          sort { $a <=> $b } @{ $opt->{constraint} };
    }

    # HBox for buttons
    my $hbox = Gtk3::HBox->new;
    $vbox->pack_start( $hbox, FALSE, TRUE, 0 );

    # Apply button
    my $abutton = Gtk3::Button->new_from_stock('gtk-apply');
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
    my $cbutton = Gtk3::Button->new_from_stock('gtk-cancel');
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
        $root, 0, 0, $CANVAS_POINT_SIZE, $CANVAS_POINT_SIZE,
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
            my $fleur = Gtk3::Gdk::Cursor->new('fleur');
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
            if (
                not(
                    $event->state >=  ## no critic (ProhibitMismatchedOperators)
                    'button1-mask'
                )
              )
            {
                return FALSE;
            }

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
                for ( 1 .. $#{ $opt->{constraint} } ) {
                    if (
                        $ygr < (
                            $opt->{constraint}[$_] +
                              $opt->{constraint}[ $_ - 1 ]
                        ) / 2
                      )
                    {
                        $ygr = $opt->{constraint}[ $_ - 1 ];
                        last;
                    }
                    elsif ( $_ == $#{ $opt->{constraint} } ) {
                        $ygr = $opt->{constraint}[$_];
                    }
                }
            }
            $canvas->{val}[ $widget->{index} ] = $ygr;
            ( $x, $y ) = to_canvas( $canvas, $xgr, $ygr );
            $widget->set( y => $y - $CANVAS_POINT_SIZE / 2 );
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
    my ( @xbounds, @ybounds );
    for ( @{ $canvas->{val} } ) {
        if ( not defined $ybounds[0] or $_ < $ybounds[0] ) {
            $ybounds[0] = $_;
        }
        if ( not defined $ybounds[1] or $_ > $ybounds[1] ) {
            $ybounds[1] = $_;
        }
    }
    my $opt = $canvas->{opt};
    $xbounds[0] = 0;
    $xbounds[1] = $#{ $canvas->{val} };
    if ( $xbounds[0] >= $xbounds[1] ) {
        $xbounds[0] = -$CANVAS_MIN_WIDTH / 2;
        $xbounds[1] = $CANVAS_MIN_WIDTH / 2;
    }
    if ( $opt->{constraint_type} == SANE_CONSTRAINT_RANGE ) {
        $ybounds[0] = $opt->{constraint}{min};
        $ybounds[1] = $opt->{constraint}{max};
    }
    elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST ) {
        $ybounds[0] = $opt->{constraint}[0];
        $ybounds[1] = $opt->{constraint}[ $#{ $opt->{constraint} } ];
    }
    my ( $vwidth, $vheight ) =
      ( $xbounds[1] - $xbounds[0], $ybounds[1] - $ybounds[0] );

    # Calculate bounds of canvas
    my ( $x, $y, $cwidth, $cheight ) = $canvas->allocation->values;

    # Calculate scale factors
    my @scale = (
        ( $cwidth - $canvas->{border} * 2 ) / $vwidth,
        ( $cheight - $canvas->{border} * 2 ) / $vheight
    );

    $canvas->{scale} = \@scale;
    $canvas->{bounds} =
      [ $xbounds[0], $ybounds[0], $xbounds[1], $xbounds[1] ];
    $canvas->{cheight} = $cheight;

    # Update canvas
    for ( 0 .. $#{ $canvas->{items} } ) {
        my $item = $canvas->{items}[$_];
        $item->{index} = $_;
        my ( $xc, $yc ) = to_canvas( $canvas, $_, $canvas->{val}[$_] );
        $item->set(
            x => $xc - $CANVAS_BORDER / 2,
            y => $yc - $CANVAS_BORDER / 2
        );
    }
    return;
}

# Set options to profile referenced by hashref

sub set_current_scan_options {
    my ( $self, $profile ) = @_;
    if ( not defined $profile ) {
        $logger->error('Cannot add undefined profile');
        return;
    }
    elsif ( ref($profile) ne 'Gscan2pdf::Scanner::Profile' ) {
        $logger->error(
            ref($profile) . ' is not a Gscan2pdf::Scanner::Profile object' );
        return;
    }

    # First clone the profile, as otherwise it would be self-modifying
    my $clone = dclone($profile);

    push @{ $self->{setting_current_scan_options} }, $clone->{uuid};

    # Give the GUI a chance to catch up between settings,
    # in case they have to be reloaded.
    # Use the callback to trigger the next loop
    $self->_set_option_profile( $clone, $clone->each_backend_option );
    return $clone->{uuid};
}

sub _set_option_profile {
    my ( $self, $profile, $next, $step ) = @_;

    if ( my $i = $next->($step) ) {
        my ( $name, $val ) = $profile->get_backend_option_by_index($i);

        my $options = $self->get('available-scan-options');
        my $opt     = $options->by_name($name);
        if ( not defined $opt or $opt->{cap} & SANE_CAP_INACTIVE ) {
            $logger->warn("Ignoring inactive option '$name'.");
            $self->_set_option_profile( $profile, $next );
            return;
        }

        $logger->debug(
            "Setting option '$name'"
              . (
                  $opt->{type} == SANE_TYPE_BUTTON
                ? $EMPTY
                : " from '$opt->{val}' to '$val'."
              )
        );
        my $signal;
        $signal = $self->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $optname, $optval, $uuid ) = @_;

                # With multiple reloads, this can get called several times,
                # so only react to to signal from the correct profile
                if ( defined $uuid and $uuid eq $profile->{uuid} ) {
                    $self->signal_handler_disconnect($signal);
                    $self->_set_option_profile( $profile, $next );
                }
            }
        );
        $self->set_option( $opt, $val, $profile->{uuid} );
        $self->update_widget_value( $opt, $val );
    }
    else {

        # Having set all backend options, set the frontend options
        my $iter = $profile->each_frontend_option;
        while ( my $key = $iter->() ) {
            $self->set( $key, $profile->get_frontend_option($key) );
        }

        if ( not @{ $self->{setting_profile} } ) {
            $self->set( 'profile', undef );
        }
        pop @{ $self->{setting_current_scan_options} };
        $self->signal_emit(
            'changed-current-scan-options',
            $self->get('current-scan-options'),
            $profile->{uuid}
        );
    }
    return;
}

sub update_widget_value {
    my ( $self, $opt, $val ) = @_;
    my $widget = $self->{option_widgets}{ $opt->{name} };
    if ( defined $widget ) {
        $logger->debug( "Setting widget '$opt->{name}'"
              . ( $opt->{type} == SANE_TYPE_BUTTON ? $EMPTY : " to '$val'." ) );
        $widget->signal_handler_block( $widget->{signal} );
        given ($widget) {
            when ( $widget->isa('Gtk3::CheckButton') ) {
                if ( $val eq $EMPTY ) { $val = 0 }
                if ( $widget->get_active != $val ) {
                    $widget->set_active($val);
                }
            }
            when ( $widget->isa('Gtk3::SpinButton') ) {
                if ( $widget->get_value != $val ) {
                    $widget->set_value($val);
                }
            }
            when ( $widget->isa('Gtk3::ComboBox') ) {
                if ( $opt->{constraint}[ $widget->get_active ] ne $val ) {
                    my $index;
                    for ( 0 .. $#{ $opt->{constraint} } ) {
                        if ( $opt->{constraint}[$_] eq $val ) {
                            $index = $_;
                        }
                    }
                    if ( defined $index ) { $widget->set_active($index) }
                }
            }
            when ( $widget->isa('Gtk3::Entry') ) {
                if ( $widget->get_text ne $val ) {
                    $widget->set_text($val);
                }
            }
        }
        $widget->signal_handler_unblock( $widget->{signal} );
    }
    else {
        $logger->warn("Widget for option '$opt->{name}' undefined.");
    }
    return;
}

sub make_progress_string {
    my ( $i, $npages ) = @_;
    return sprintf __('Scanning page %d of %d'), $i, $npages
      if ( $npages > 0 );
    return sprintf __('Scanning page %d'), $i;
}

1;

__END__
