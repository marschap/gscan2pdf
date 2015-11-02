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
];

our $VERSION = '1.3.5';

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
            use Data::Dumper;
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
    $self->{profile}       = undef;
    $self->{paper_formats} = undef;
    $self->{paper}         = undef;

    delete $self->{combobp}; # So we don't carry over from one device to another
    for ( 1 .. $num_dev_options - 1 ) {
        my $opt = $options->by_index($_);

        # Notebook page for group
        if ( $opt->{type} == SANE_TYPE_GROUP or not defined $vbox ) {
            $vbox = Gtk2::VBox->new;
            $group =
                $opt->{type} == SANE_TYPE_GROUP
              ? $d_sane->get( $opt->{title} )
              : $d->get('Scan Options');
            $self->{notebook}->append_page( $vbox, $group );
            next;
        }

        if ( not( $opt->{cap} & SANE_CAP_SOFT_DETECT ) ) { next }

        # Widget
        my ( $widget, $val );
        $val = $opt->{val};

        # Define HBox for paper size here
        # so that it can be put before first geometry option
        if ( $self->_geometry_option($opt) and not defined $hboxp ) {
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

    # Set defaults
    my $sane_device = Gscan2pdf::Frontend::Sane->device();

    # Show new pages
    for ( 1 .. $self->{notebook}->get_n_pages - 1 ) {
        $self->{notebook}->get_nth_page($_)->show_all;
    }

    $self->{sbutton}->set_sensitive(TRUE);
    $self->{sbutton}->grab_focus;
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
            defined( $options->{box}{$SANE_NAME_SCAN_BR_X} )
        and defined( $options->{box}{$SANE_NAME_SCAN_BR_Y} )
        and defined( $options->{box}{$SANE_NAME_SCAN_TL_X} )
        and defined( $options->{box}{$SANE_NAME_SCAN_TL_Y} )
        and ( not defined $options->by_name(SANE_NAME_PAGE_HEIGHT)
            or defined( $options->{box}{$SANE_NAME_PAGE_HEIGHT} ) )
        and ( not defined $options->by_name(SANE_NAME_PAGE_WIDTH)
            or defined( $options->{box}{$SANE_NAME_PAGE_WIDTH} ) )
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
                elsif ( $self->{combobp}->get_active_text eq $d->get('Manual') )
                {
                    for (
                        ( SANE_NAME_SCAN_TL_X, SANE_NAME_SCAN_TL_Y,
                            SANE_NAME_SCAN_BR_X,   SANE_NAME_SCAN_BR_Y,
                            SANE_NAME_PAGE_HEIGHT, SANE_NAME_PAGE_WIDTH
                        )
                      )
                    {
                        if ( defined $options->{box}{$_} ) {
                            $options->{box}{$_}->show_all;
                        }
                    }
                }
                else {
                    my $paper   = $self->{combobp}->get_active_text;
                    my $formats = $self->get('paper-formats');
                    if ( defined( $options->by_name(SANE_NAME_PAGE_HEIGHT) )
                        and not $options->by_name(SANE_NAME_PAGE_HEIGHT)->{cap}
                        & SANE_CAP_INACTIVE
                        and defined( $options->by_name(SANE_NAME_PAGE_WIDTH) )
                        and not $options->by_name(SANE_NAME_PAGE_WIDTH)->{cap}
                        & SANE_CAP_INACTIVE )
                    {
                        $options->by_name(SANE_NAME_PAGE_HEIGHT)->{widget}
                          ->set_value(
                            $formats->{$paper}{y} + $formats->{$paper}{t} );
                        $options->by_name(SANE_NAME_PAGE_WIDTH)->{widget}
                          ->set_value(
                            $formats->{$paper}{x} + $formats->{$paper}{l} );
                    }

                    $options->by_name(SANE_NAME_SCAN_TL_X)->{widget}
                      ->set_value( $formats->{$paper}{l} );
                    $options->by_name(SANE_NAME_SCAN_TL_Y)->{widget}
                      ->set_value( $formats->{$paper}{t} );
                    $options->by_name(SANE_NAME_SCAN_BR_X)->{widget}
                      ->set_value(
                        $formats->{$paper}{x} + $formats->{$paper}{l} );
                    $options->by_name(SANE_NAME_SCAN_BR_Y)->{widget}
                      ->set_value(
                        $formats->{$paper}{y} + $formats->{$paper}{t} );
                    Glib::Idle->add( sub { $self->hide_geometry($options) } );

                    # Do this last, as it fires the changed-paper signal
                    $self->set( 'paper', $paper );
                }
            }
        );
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
        if ( defined $options->{box}{$_} ) { $options->{box}{$_}->hide_all; }
    }
    return;
}

# Update the sane option in the thread
# If necessary, reload the options,
# and walking the options tree, update the widgets

sub set_option {
    my ( $self, $option, $val, $finished_callback ) = @_;
    if ( not defined $option ) { return }

    $self->add_to_current_scan_options( $option, $val );

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

                $self->signal_emit(
                    'changed-current-scan-options',
                    $self->get('current-scan-options')
                );
            }

            $self->signal_emit( 'changed-scan-option', $option->{name}, $val );
            if ( defined $finished_callback ) { $finished_callback->() }
        },
        error_callback => sub {
            my ($message) = @_;
            $self->signal_emit( 'process-error', 'set_option',
                $d->get( 'Error setting option: ' . $message ) );
        },
    );
    return;
}

# If setting an option triggers a reload, we need to update the options

sub update_options {
    my ( $self, $new_options ) = @_;

    # walk the widget tree and update them from the hash
    $logger->debug( 'Sane->get_option_descriptor returned: ',
        Dumper($new_options) );

    my ( $group, $vbox );
    my $num_dev_options = $new_options->num_options;
    my $options         = $self->get('available-scan-options');
    for ( 1 .. $num_dev_options - 1 ) {
        my $widget = $options->by_index($_)->{widget};

        # could be undefined for !($new_opt->{cap} & SANE_CAP_SOFT_DETECT)
        if ( not defined $widget ) { next }

        my $new_opt = $new_options->by_index($_);
        my $opt     = $options->by_index($_);
        if ( $new_opt->{name} ne $opt->{name} ) {
            $logger->error(
'Error updating options: reloaded options are numbered differently'
            );
            return;
        }

      # We've got to block the signal handler for the widget to prevent infinite
      # loops of the widget updating the option, updating the widget, etc., but
      # therefore we must update the options manually
        for (qw(val cap max_values type constraint_type constraint)) {
            $opt->{$_} = $new_opt->{$_};
        }
        $widget->signal_handler_block( $widget->{signal} );
        my $value = $opt->{val};

        # HBox for option
        my $hbox = $widget->parent;
        $hbox->set_sensitive( ( not $opt->{cap} & SANE_CAP_INACTIVE )
              and $opt->{cap} & SANE_CAP_SOFT_SELECT );

        if ( $opt->{max_values} < 2 ) {

            # CheckButton
            if ( $opt->{type} == SANE_TYPE_BOOL )
            {    ## no critic (ProhibitCascadingIfElse)
                if ( $self->value_for_active_option( $value, $opt ) ) {
                    $widget->set_active($value);
                }
            }

            # SpinButton
            elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_RANGE ) {
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
            elsif ($opt->{constraint_type} == SANE_CONSTRAINT_STRING_LIST
                or $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST )
            {
                $widget->get_model->clear;
                my $index = 0;
                for ( 0 .. $#{ $opt->{constraint} } ) {
                    $widget->append_text(
                        $d_sane->get( $opt->{constraint}[$_] ) );
                    if ( defined $value and $opt->{constraint}[$_] eq $value ) {
                        $index = $_;
                    }
                }
                if ( defined $index ) { $widget->set_active($index) }
            }

            # Entry
            elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_NONE ) {
                if ( $self->value_for_active_option( $value, $opt ) ) {
                    $widget->set_text($value);
                }
            }
        }
        $widget->signal_handler_unblock( $widget->{signal} );
    }
    return;
}

# As scanimage and scanadf rename the geometry options,
# we have to map them back to the original names
sub map_geometry_names {
    my ( $self, $profile ) = @_;
    for my $i ( 0 .. $#{$profile} ) {

        # for reasons I don't understand, without walking the reference tree,
        # parts of $profile are undef
        Gscan2pdf::Dialog::Scan::my_dumper( $profile->[$i] );
        my ( $name, $val ) = each %{ $profile->[$i] };
        given ($name) {
            when ('l') {
                $name = SANE_NAME_SCAN_TL_X;
                $profile->[$i] = { $name => $val };
            }
            when ('t') {
                $name = SANE_NAME_SCAN_TL_Y;
                $profile->[$i] = { $name => $val };
            }
            when ('x') {
                $name = SANE_NAME_SCAN_BR_X;
                my $l = $self->get_option_from_profile( 'l', $profile );
                if ( not defined $l ) {
                    $l =
                      $self->get_option_from_profile( SANE_NAME_SCAN_TL_X,
                        $profile );
                }
                if ( defined $l ) { $val += $l; }
                $profile->[$i] = { $name => $val };
            }
            when ('y') {
                $name = SANE_NAME_SCAN_BR_Y;
                my $t = $self->get_option_from_profile( 't', $profile );
                if ( not defined $t ) {
                    $t =
                      $self->get_option_from_profile( SANE_NAME_SCAN_TL_Y,
                        $profile );
                }
                if ( defined $t ) { $val += $t; }
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
            $self->signal_emit( 'started-process',
                Gscan2pdf::Dialog::Scan::make_progress_string( $i, $npages ) );
        },
        running_callback => sub {
            my ($progress) = @_;
            $self->signal_emit( 'changed-progress', $progress, undef );
        },
        finished_callback => sub {
            $self->signal_emit( 'finished-process', 'scan_pages' );
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
