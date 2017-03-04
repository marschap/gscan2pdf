package Gscan2pdf::Dialog::Scan::Sane;

use warnings;
use strict;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use Gscan2pdf::Dialog::Scan;
use Glib qw(TRUE FALSE);   # To get TRUE and FALSE
use Sane 0.05;             # To get SANE_NAME_PAGE_WIDTH & SANE_NAME_PAGE_HEIGHT
use Gscan2pdf::Frontend::Sane;
use Locale::gettext 1.05;    # For translations
use feature 'switch';
use Data::Dumper;
use Readonly;
Readonly my $LAST_PAGE => -1;

# logger duplicated from Gscan2pdf::Dialog::Scan
# to ensure that SET_PROPERTIES gets called in both places
use Glib::Object::Subclass Gscan2pdf::Dialog::Scan::, properties => [
    Glib::ParamSpec->scalar(
        'logger',                              # name
        'Logger',                              # nick
        'Log::Log4perl::get_logger object',    # blurb
        [qw/readable writable/]                # flags
    ),
    Glib::ParamSpec->boolean(
        'cycle-sane-handle',                                             # name
        'Cycle SANE handle after scan',                                  # nick
        'In some scanners, this allows the ADF to eject the last page',  # blurb
        FALSE,                     # default_value
        [qw/readable writable/]    # flags
    ),
];

our $VERSION = '1.7.3';

my $SANE_NAME_SCAN_TL_X   = SANE_NAME_SCAN_TL_X;
my $SANE_NAME_SCAN_TL_Y   = SANE_NAME_SCAN_TL_Y;
my $SANE_NAME_SCAN_BR_X   = SANE_NAME_SCAN_BR_X;
my $SANE_NAME_SCAN_BR_Y   = SANE_NAME_SCAN_BR_Y;
my $SANE_NAME_PAGE_HEIGHT = SANE_NAME_PAGE_HEIGHT;
my $SANE_NAME_PAGE_WIDTH  = SANE_NAME_PAGE_WIDTH;
my $EMPTY                 = q{};
my ( $d, $d_sane, $logger, $tooltips );

sub INIT_INSTANCE {
    my $self = shift;
    $tooltips = Gtk2::Tooltips->new;
    $tooltips->enable;

    $d      = Locale::gettext->domain(Glib::get_application_name);
    $d_sane = Locale::gettext->domain('sane-backends');
    return $self;
}

sub SET_PROPERTY {
    my ( $self, $pspec, $newval ) = @_;
    my $name   = $pspec->get_name;
    my $oldval = $self->get($name);
    $self->{$name} = $newval;
    if (   ( defined $newval and defined $oldval and $newval ne $oldval )
        or ( defined $newval xor defined $oldval ) )
    {
        if ( $name eq 'logger' ) {
            $logger = $newval;
            $logger->debug('Set logger in Gscan2pdf::Dialog::Scan::Sane');
        }
    }
    $self->SUPER::SET_PROPERTY( $pspec, $newval );
    return;
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
            $pbar->set_pulse_step( $self->get('progress-pulse-step') );
            $pbar->set_text( $d->get('Fetching list of devices') );
            $hboxd->pack_start( $pbar, TRUE, TRUE, 0 );
            $hboxd->hide_all;
            $hboxd->show;
            $pbar->show;
        },
        sub {
            $pbar->pulse;
        },
        sub {
            my ($data) = @_;
            $pbar->destroy;
            my @device_list = @{$data};
            $logger->info( 'Sane->get_devices returned: ',
                Dumper( \@device_list ) );
            if ( @device_list == 0 ) {
                $self->signal_emit( 'process-error', 'get_devices',
                    $d->get('No devices found') );
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
        $self->{notebook}->remove_page($LAST_PAGE);
    }

    # Remove lookups to geometry boxes and option widgets
    delete $self->{geometry_boxes};
    delete $self->{option_widgets};

    # Ghost the scan button whilst options being updated
    if ( defined $self->{sbutton} ) { $self->{sbutton}->set_sensitive(FALSE) }

    my $signal;
    Gscan2pdf::Frontend::Sane->open_device(
        device_name      => $self->get('device'),
        started_callback => sub {
            $self->signal_emit( 'started-process', $d->get('Opening device') );
        },
        running_callback => sub {
            $self->signal_emit( 'changed-progress', undef, undef );
        },
        finished_callback => sub {
            $self->signal_emit( 'finished-process', 'open_device' );
            Gscan2pdf::Frontend::Sane->find_scan_options(
                sub {    # started callback
                    $self->signal_emit( 'started-process',
                        $d->get('Retrieving options') );
                },
                sub {    # running callback
                    $self->signal_emit( 'changed-progress', undef, undef );
                },
                sub {    # finished callback
                    my ($data) = @_;
                    my $options =
                      Gscan2pdf::Scanner::Options->new_from_data($data);
                    $self->_initialise_options($options);

                    $self->signal_emit( 'finished-process',
                        'find_scan_options' );

                    # This fires the reloaded-scan-options signal,
                    # so don't set this until we have finished
                    $self->set( 'available-scan-options', $options );
                    $self->set_paper_formats( $self->{paper_formats} );
                },
                sub {    # error callback
                    my ($message) = @_;
                    $self->signal_emit(
                        'process-error',
                        'find_scan_options',
                        $d->get(
                            'Error retrieving scanner options: ' . $message
                        )
                    );
                }
            );
        },
        error_callback => sub {
            my ($message) = @_;
            $self->signal_emit( 'process-error', 'open_device',
                $d->get( 'Error opening device: ' . $message ) );
        }
    );
    return;
}

sub _initialise_options {    ## no critic (ProhibitExcessComplexity)
    my ( $self, $options ) = @_;
    $logger->debug( 'Sane->get_option_descriptor returned: ',
        Dumper($options) );

    my ( $group, $vbox, $hboxp );
    my $num_dev_options = $options->num_options;

    # We have hereby removed the active profile and paper,
    # so update the properties without triggering the signals
    $self->{profile} = undef;
    $self->{paper}   = undef;

    delete $self->{combobp}; # So we don't carry over from one device to another
    for ( 1 .. $num_dev_options - 1 ) {
        my $opt = $options->by_index($_);

        # Notebook page for group
        if ( $opt->{type} == SANE_TYPE_GROUP or not defined $vbox ) {
            $vbox = Gtk2::VBox->new;
            $vbox->set_border_width( $self->get('border-width') );
            $group =
                $opt->{type} == SANE_TYPE_GROUP
              ? $d_sane->get( $opt->{title} )
              : $d->get('Scan Options');
            my $scwin = Gtk2::ScrolledWindow->new;
            $self->{notebook}->append_page( $scwin, $group );
            $scwin->set_policy( 'automatic', 'automatic' );
            $scwin->add_with_viewport($vbox);
            if ( $opt->{type} == SANE_TYPE_GROUP ) { next }
        }

        if ( not( $opt->{cap} & SANE_CAP_SOFT_DETECT ) ) { next }

        # Widget
        my ( $widget, $val );
        $val = $opt->{val};

        # Define HBox for paper size here
        # so that it can be put before first geometry option
        if ( not defined $hboxp and $self->_geometry_option($opt) ) {
            $hboxp = Gtk2::HBox->new;
            $vbox->pack_start( $hboxp, FALSE, FALSE, 0 );
        }

        # HBox for option
        my $hbox = Gtk2::HBox->new;
        $vbox->pack_start( $hbox, FALSE, TRUE, 0 );
        if ( $opt->{cap} & SANE_CAP_INACTIVE
            or not $opt->{cap} & SANE_CAP_SOFT_SELECT )
        {
            $hbox->set_sensitive(FALSE);
        }

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
                if ($val) { $widget->set_active(TRUE) }
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
                if ( $opt->{constraint}{quant} ) {
                    $step = $opt->{constraint}{quant};
                }
                $widget =
                  Gtk2::SpinButton->new_with_range( $opt->{constraint}{min},
                    $opt->{constraint}{max}, $step );

                # Set the default
                if ( defined $val and not $opt->{cap} & SANE_CAP_INACTIVE ) {
                    $widget->set_value($val);
                }
                $widget->{signal} = $widget->signal_connect(
                    'value-changed' => sub {
                        my $value = $widget->get_value;
                        $self->set_option( $opt, $value );
                    }
                );
            }

            # ComboBox
            elsif ($opt->{constraint_type} == SANE_CONSTRAINT_STRING_LIST
                or $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST )
            {
                $widget = Gtk2::ComboBox->new_text;
                my $index = 0;
                for ( 0 .. $#{ $opt->{constraint} } ) {
                    $widget->append_text(
                        $d_sane->get( $opt->{constraint}[$_] ) );
                    if ( defined $val and $opt->{constraint}[$_] eq $val ) {
                        $index = $_;
                    }
                }

                # Set the default
                if ( defined $index ) { $widget->set_active($index) }
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
                if ( defined $val and not $opt->{cap} & SANE_CAP_INACTIVE ) {
                    $widget->set_text($val);
                }
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
                clicked => \&multiple_values_button_callback,
                [ $self, $opt ]
            );
        }

        $self->pack_widget( $widget, [ $options, $opt, $hbox, $hboxp ] );
    }

    # Show new pages
    for ( 1 .. $self->{notebook}->get_n_pages - 1 ) {
        $self->{notebook}->get_nth_page($_)->show_all;
    }

    $self->{sbutton}->set_sensitive(TRUE);
    $self->{sbutton}->grab_focus;
    return;
}

# Update the sane option in the thread
# If necessary, reload the options,
# and walking the options tree, update the widgets

sub set_option {
    my ( $self, $option, $val ) = @_;
    if ( not defined $option ) { return }

    $self->{current_scan_options}->add_backend_option( $option->{name}, $val );

    my $signal;
    my $options = $self->get('available-scan-options');
    Gscan2pdf::Frontend::Sane->set_option(
        index            => $option->{index},
        value            => $val,
        started_callback => sub {
            $self->signal_emit( 'started-process',
                sprintf $d->get('Setting option %s'),
                $option->{name} );
        },
        running_callback => sub {
            $self->signal_emit( 'changed-progress', undef, undef );
        },
        finished_callback => sub {
            my ($data) = @_;
            if ($data) {
                $self->update_options(
                    Gscan2pdf::Scanner::Options->new_from_data($data) );
            }
            else {
                my $opt = $options->by_name( $option->{name} );
                $opt->{val} = $val;
            }

            # We can carry on applying defaults now, if necessary.
            $self->signal_emit( 'finished-process',
                "set_option $option->{name} to $val" );

            # Unset the profile unless we are actively setting it
            if ( not $self->{setting_profile} ) {
                $self->set( 'profile', undef );

                # Emit the changed-current-scan-options signal
                # unless we are actively setting it
                if ( not $self->{setting_current_scan_options} ) {
                    $self->signal_emit(
                        'changed-current-scan-options',
                        $self->get('current-scan-options')
                    );
                }
            }

            $self->signal_emit( 'changed-scan-option', $option->{name}, $val );
        },
        error_callback => sub {
            my ($message) = @_;
            $self->signal_emit( 'process-error', 'set_option',
                $d->get( 'Error setting option: ' . $message ) );
        },
    );
    return;
}

sub scan {
    my ($self) = @_;

    # Get selected number of pages
    my $npages = $self->get('num-pages');
    my $start  = $self->get('page-number-start');
    my $step   = $self->get('page-number-increment');
    if ( $npages > 0 and $step < 0 ) { $npages = $self->get('max-pages') }

    if ( $start == 1 and $step < 0 ) {
        $self->signal_emit( 'process-error', 'scan',
            $d->get('Must scan facing pages first') );
        return TRUE;
    }

    my $i = 1;
    Gscan2pdf::Frontend::Sane->scan_pages(
        dir              => $self->get('dir'),
        npages           => $npages,
        start            => $start,
        step             => $step,
        started_callback => sub {
            if ( $npages == 0 and $self->get('max-pages') > 0 ) {
                $npages = $self->get('max-pages');
            }
            $logger->info("Scanning $npages pages from $start with step $step");
            $self->signal_emit( 'started-process',
                Gscan2pdf::Dialog::Scan::make_progress_string( $i, $npages ) );
        },
        running_callback => sub {
            my ($progress) = @_;
            $self->signal_emit( 'changed-progress', $progress, undef );
        },
        finished_callback => sub {
            $self->signal_emit( 'finished-process', 'scan_pages' );

            if ( $self->get('cycle-sane-handle') ) {
                my $current = $self->get('current-scan-options');
                $self->scan_options( $self->get('device') );
                $self->set_current_scan_options($current);
            }
        },
        new_page_callback => sub {
            my ( $status, $path, $n ) = @_;
            $self->signal_emit( 'new-scan', $path, $n );
            $self->signal_emit( 'changed-progress', 0,
                Gscan2pdf::Dialog::Scan::make_progress_string( ++$i, $npages )
            );
        },
        error_callback => sub {
            my ($msg) = @_;
            $self->signal_emit( 'process-error', 'scan_pages', $msg );
        }
    );
    return;
}

sub cancel_scan {
    Gscan2pdf::Frontend::Sane->cancel_scan;
    $logger->info('Cancelled scan');
    return;
}

1;

__END__
