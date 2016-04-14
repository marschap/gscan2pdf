package Gscan2pdf::Dialog::Scan::CLI;

use warnings;
use strict;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use Gscan2pdf::Dialog::Scan;
use Glib qw(TRUE FALSE);   # To get TRUE and FALSE
use Sane 0.05;             # To get SANE_NAME_PAGE_WIDTH & SANE_NAME_PAGE_HEIGHT
use Gscan2pdf::Frontend::CLI;
use Storable qw(dclone);     # For cloning the options cache
use Locale::gettext 1.05;    # For translations
use feature 'switch';
use List::MoreUtils qw{any};
use Data::Dumper;

my ( $d, $d_sane, $logger, $tooltips, $EMPTY, $COMMA );

# otherwise older version of perl complain that $EMPTY is not defined
# in the subclass
BEGIN {
    $EMPTY = q{};
    $COMMA = q{,};
}

# logger duplicated from Gscan2pdf::Dialog::Scan
# to ensure that SET_PROPERTIES gets called in both places
use Glib::Object::Subclass Gscan2pdf::Dialog::Scan::, signals => {
    'changed-cache-options' => {
        param_types => ['Glib::Boolean'],    # new value
    },
    'changed-options-cache' => {
        param_types => ['Glib::Scalar'],     # new value
    },
    'fetched-options-cache' => {
        param_types => [ 'Glib::String', 'Glib::String' ],   # device, cache key
    },
  },
  properties => [
    Glib::ParamSpec->string(
        'frontend',                                          # name
        'Frontend',                                          # nick
        '(scanimage|scanadf)(-perl)?',                       # blurb
        'scanimage',                                         # default
        [qw/readable writable/]                              # flags
    ),
    Glib::ParamSpec->scalar(
        'logger',                                            # name
        'Logger',                                            # nick
        'Log::Log4perl::get_logger object',                  # blurb
        [qw/readable writable/]                              # flags
    ),
    Glib::ParamSpec->string(
        'prefix',                                            # name
        'Prefix',                                            # nick
        'Prefix for command line calls',                     # blurb
        $EMPTY,                                              # default
        [qw/readable writable/]                              # flags
    ),
    Glib::ParamSpec->scalar(
        'reload-triggers',                                               # name
        'Reload triggers',                                               # nick
        'Array of option names that cause the options to be reloaded',   # blurb
        [qw/readable writable/]                                          # flags
    ),
    Glib::ParamSpec->boolean(
        'cache-options',               # name
        'Cache options',               # nickname
        'Whether to cache options',    # blurb
        FALSE,                         # default
        [qw/readable writable/]        # flags
    ),
    Glib::ParamSpec->scalar(
        'options-cache',                               # name
        'Options cache',                               # nick
        'Hash containing cache of scanner options',    # blurb
        [qw/readable writable/]                        # flags
    ),
  ];

our $VERSION = '1.4.0';

my $SANE_NAME_PAGE_HEIGHT = SANE_NAME_PAGE_HEIGHT;
my $SANE_NAME_PAGE_WIDTH  = SANE_NAME_PAGE_WIDTH;

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
            $logger->debug('Set logger in Gscan2pdf::Dialog::Scan::CLI');
        }
        elsif ( $name eq 'cache_options' ) {
            $self->signal_emit( 'changed-cache-options', $newval );
        }
        elsif ( $name eq 'options_cache' ) {
            $self->signal_emit( 'changed-options-cache', $newval );
        }
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
            $pbar->set_pulse_step( $self->get('progress-pulse-step') );
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
            $logger->info( 'scanimage --formatted-device-list: ',
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

# Return cache key based on reload triggers and given options

sub cache_key {
    my ( $self, $options ) = @_;

    my $reload_triggers = $self->get('reload-triggers');
    if ( not defined $reload_triggers ) { return 'default' }

    if ( ref($reload_triggers) ne 'ARRAY' ) {
        $reload_triggers = [$reload_triggers];
    }

    my $cache_key = $EMPTY;
    if ( defined $options ) {

        for my $opt ( @{ $options->{array} } ) {
            for ( @{$reload_triggers} ) {
                if ( defined( $opt->{name} ) and /^$opt->{name}$/ixsm ) {
                    if ( $cache_key ne $EMPTY ) { $cache_key .= $COMMA }
                    $cache_key .= "$opt->{name},$opt->{val}";
                    last;
                }
            }
        }
    }
    else {

        # for reasons I don't understand, without walking the reference tree,
        # parts of $default are undef
        Dumper( $self->{current_scan_options} );

        # grep the reload triggers from the current options
        for ( @{ $self->{current_scan_options} } ) {
            my ( $key, $value ) = each %{$_};
            for ( @{$reload_triggers} ) {
                if (/^$key$/ixsm) {
                    if ( $cache_key ne $EMPTY ) { $cache_key .= $COMMA }
                    $cache_key .= "$key,$value";
                    last;
                }
            }
        }

    }

    if ( $cache_key eq $EMPTY ) { $cache_key = 'default' }
    return $cache_key;
}

# Scan device-dependent scan options

sub scan_options {
    my ($self) = @_;

    # Remove any existing pages
    while ( $self->{notebook}->get_n_pages > 1 ) {

        # -1 = last page
        $self->{notebook}->remove_page(-1);  ## no critic (ProhibitMagicNumbers)
    }

    # Ghost the scan button whilst options being updated
    if ( defined $self->{sbutton} ) { $self->{sbutton}->set_sensitive(FALSE) }

    my ( $pbar, $cache_key );
    my $hboxd = $self->{hboxd};
    if ( $self->get('cache-options') ) {
        $cache_key = $self->cache_key;

        my $cache = $self->get('options-cache');
        if ( defined $cache->{ $self->get('device') }{$cache_key} ) {
            my $options = Gscan2pdf::Scanner::Options->new_from_data(
                $cache->{ $self->get('device') }{$cache_key} );
            $self->signal_emit( 'fetched-options-cache', $self->get('device'),
                $cache_key );
            $logger->info($options);
            $self->_initialise_options($options);

            $self->signal_emit( 'finished-process', 'find_scan_options' );

            # This fires the reloaded-scan-options signal,
            # so don't set this until we have finished
            $self->set( 'available-scan-options', $options );
            $self->set_paper_formats( $self->{paper_formats} );
            return;
        }
    }

    Gscan2pdf::Frontend::CLI->find_scan_options(
        prefix           => $self->get('prefix'),
        frontend         => $self->get('frontend'),
        device           => $self->get('device'),
        options          => $self->{current_scan_options},
        started_callback => sub {

            # Set up ProgressBar
            $pbar = Gtk2::ProgressBar->new;
            $pbar->set_pulse_step( $self->get('progress-pulse-step') );
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
            $hboxd->show_all;
            if ( $self->get('cache-options') ) {
                my $cache = $self->get('options-cache');

        # Don't assume that the options we have are those we are looking for yet
        # Recalculating cache_key based on contents of options
                if ( $cache_key ne 'default' ) {
                    $cache_key = $self->cache_key($options);
                }

                # We only store the array part of the options object
                # as we have to recreate the object anyway when we retrieve it
                my $clone  = dclone( $options->{array} );
                my $device = $self->get('device');
                if ( defined $cache ) {
                    $cache->{$device}{$cache_key} = $clone;
                }
                else {
                    $cache->{$device}{$cache_key} = $clone;
                    if ( $cache_key eq 'default' ) {

     # For default settings, additionally store the cache under the option names
                        $cache_key = $self->cache_key($options);
                        $cache->{$device}{$cache_key} =
                          $cache->{$device}{default};

                    }
                }
                $self->set( 'options-cache', $cache );
                $self->signal_emit( 'changed-options-cache', $cache );
            }
            $self->_initialise_options($options);

            $self->signal_emit( 'finished-process', 'find_scan_options' );

            # This fires the reloaded-scan-options signal,
            # so don't set this until we have finished
            $self->set( 'available-scan-options', $options );
            $self->set_paper_formats( $self->{paper_formats} );
        },
        error_callback => sub {
            my ($message) = @_;
            $pbar->destroy;
            $self->signal_emit( 'process-error', 'find_scan_options',
                $message );
            $logger->warn($message);
        },
    );
    return;
}

sub _initialise_options {    ## no critic (ProhibitExcessComplexity)
    my ( $self, $options ) = @_;
    $logger->debug( 'scanimage --help returned: ', Dumper($options) );

    my $num_dev_options = $options->num_options;

    # We have hereby removed the active profile and paper,
    # so update the properties without triggering the signals
    $self->{profile} = undef;
    $self->{paper}   = undef;

    # Default tab
    my $vbox = Gtk2::VBox->new;
    $self->{notebook}->append_page( $vbox, $d->get('Scan Options') );

    delete $self->{combobp}; # So we don't carry over from one device to another
    for ( 1 .. $num_dev_options - 1 ) {
        my $opt = $options->by_index($_);

        # Notebook page for group
        if ( $opt->{type} == SANE_TYPE_GROUP ) {
            $vbox = Gtk2::VBox->new;
            $self->{notebook}
              ->append_page( $vbox, $d_sane->get( $opt->{title} ) );
            $opt->{widget} = $vbox;
            next;
        }

        if ( not( $opt->{cap} & SANE_CAP_SOFT_DETECT ) ) { next }

        # Widget
        my ( $widget, $val );
        $val = $opt->{val};

        # Define HBox for paper size here
        # so that it can be put before first geometry option
        if ( $self->_geometry_option($opt) and not defined( $self->{hboxp} ) ) {
            $self->{hboxp} = Gtk2::HBox->new;
            $vbox->pack_start( $self->{hboxp}, FALSE, FALSE, 0 );
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

        $self->pack_widget( $widget, [ $options, $opt, $hbox ] );
    }

    # Callback for option visibility
    $self->signal_connect(
        'changed-option-visibility' => sub {
            my ( $widget, $visible_options ) = @_;
            $self->_update_option_visibility( $options, $visible_options );
        }
    );
    $self->_update_option_visibility( $options,
        $self->get('visible-scan-options') );

    $self->{sbutton}->set_sensitive(TRUE);
    $self->{sbutton}->grab_focus;
    return;
}

sub _update_option_visibility {
    my ( $self, $options, $visible_options ) = @_;

    # Show all notebook tabs
    for ( 1 .. $self->{notebook}->get_n_pages - 1 ) {
        $self->{notebook}->get_nth_page($_)->show_all;
    }

    my $num_dev_options = $options->num_options;
    for ( 1 .. $num_dev_options - 1 ) {
        my $opt = $options->{array}[$_];
        my $show;
        if ( defined $visible_options->{ $opt->{name} } ) {
            $show = $visible_options->{ $opt->{name} };
        }
        elsif ( defined $visible_options->{ $opt->{title} } ) {
            $show = $visible_options->{ $opt->{title} };
        }
        my $container =
            $opt->{type} == SANE_TYPE_GROUP
          ? $opt->{widget}
          : $opt->{widget}->parent;
        my $geometry = $self->_geometry_option($opt);
        if ($show) {
            $container->show_all;

            # Find associated group
            next if ( $opt->{type} == SANE_TYPE_GROUP );
            my $j = $_;
            while ( --$j > 0
                and $options->{array}[$j]{type} != SANE_TYPE_GROUP )
            {
            }
            if ( $j > 0 and not $options->{array}[$j]{widget}->visible ) {
                my $group = $options->{array}[$j]{widget};
                if ( not $group->visible ) {
                    $group->remove($container);
                    my $move_paper =
                      (       $geometry
                          and defined( $self->{hboxp} )
                          and $self->{hboxp}->parent eq $group );
                    if ($move_paper) { $group->remove( $self->{hboxp} ) }

                    # Find visible group
                    $group = $self->_find_visible_group( $options, $j );
                    if ($move_paper) {
                        $group->pack_start( $self->{hboxp}, FALSE, FALSE, 0 );
                    }
                    $group->pack_start( $container, FALSE, FALSE, 0 );
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

sub _find_visible_group {
    my ( $self, $options, $option_number ) = @_;
    while (
        --$option_number > 0
        and ( $options->{array}[$option_number]{type} != SANE_TYPE_GROUP
            or ( not $options->{array}[$option_number]{widget}->visible ) )
      )
    {
    }
    return $options->{array}[$option_number]{widget}
      if ( $option_number > 0 );
    return $self->{notebook}->get_nth_page(1);
}

# Return true if we have a valid geometry option

sub _geometry_option {
    my ( $self, $opt ) = @_;
    return (
        ( $opt->{type} == SANE_TYPE_FIXED or $opt->{type} == SANE_TYPE_INT )
          and
          ( $opt->{unit} == SANE_UNIT_MM or $opt->{unit} == SANE_UNIT_PIXEL )
          and ( $opt->{name} =~
            /^(?:[ltxy]|$SANE_NAME_PAGE_HEIGHT|$SANE_NAME_PAGE_WIDTH)$/xsm )
    );
}

# Return true if all the geometry widgets have been created

sub _geometry_widgets_created {
    my ($options) = @_;
    return (
              defined( $options->{box}{x} )
          and defined( $options->{box}{y} )
          and defined( $options->{box}{l} )
          and defined( $options->{box}{t} )
          and ( not defined $options->by_name(SANE_NAME_PAGE_HEIGHT)
            or defined( $options->{box}{$SANE_NAME_PAGE_HEIGHT} ) )
          and ( not defined $options->by_name(SANE_NAME_PAGE_WIDTH)
            or defined( $options->{box}{$SANE_NAME_PAGE_WIDTH} ) )
    );
}

sub create_paper_widget {
    my ( $self, $options ) = @_;

    # Only define the paper size once the rest of the geometry widgets
    # have been created
    if (    _geometry_widgets_created($options)
        and not defined( $self->{combobp} )
        and defined( $self->{hboxp} ) )
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
                if ( not defined $self->{combobp}->get_active_text ) { return }

                if ( $self->{combobp}->get_active_text eq $d->get('Edit') ) {
                    $self->edit_paper;
                }
                elsif ( $self->{combobp}->get_active_text eq $d->get('Manual') )
                {
                    for (
                        (
                            'l', 't', 'x', 'y', SANE_NAME_PAGE_HEIGHT,
                            SANE_NAME_PAGE_WIDTH
                        )
                      )
                    {
                        if ( defined $options->{box}{$_} ) {
                            $options->{box}{$_}->show_all;
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
            ( 'l', 't', 'x', 'y', SANE_NAME_PAGE_HEIGHT, SANE_NAME_PAGE_WIDTH )
          )
        {
            if ( defined $options->by_name($_) ) {
                my $widget = $options->by_name($_)->{widget};
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
        if ( $_ eq $paper ) { return }
    }
    my $formats = $self->get('paper-formats');
    my $options = $self->get('available-scan-options');
    my @paper_profile;
    if ( defined( $options->by_name(SANE_NAME_PAGE_HEIGHT) )
        and not $options->by_name(SANE_NAME_PAGE_HEIGHT)->{cap} &
        SANE_CAP_INACTIVE
        and defined( $options->by_name(SANE_NAME_PAGE_WIDTH) )
        and not $options->by_name(SANE_NAME_PAGE_WIDTH)->{cap} &
        SANE_CAP_INACTIVE )
    {
        $self->build_profile(
            \@paper_profile,
            $options->by_name(SANE_NAME_PAGE_HEIGHT),
            $formats->{$paper}{y} + $formats->{$paper}{t}
        );
        $self->build_profile(
            \@paper_profile,
            $options->by_name(SANE_NAME_PAGE_WIDTH),
            $formats->{$paper}{x} + $formats->{$paper}{l}
        );
    }
    for (qw( l t x y )) {
        $self->build_profile(
            \@paper_profile,
            $options->by_name($_),
            $formats->{$paper}{$_}
        );
    }

    if ( not @paper_profile ) {
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

# Don't trigger the changed-paper signal until we have finished setting the profile
    $self->{setting_profile} = TRUE;
    $self->_set_option_profile( 0, \@paper_profile );
    return;
}

sub hide_geometry {
    my ( $self, $options ) = @_;
    for ( ( 'l', 't', 'x', 'y', SANE_NAME_PAGE_HEIGHT, SANE_NAME_PAGE_WIDTH ) )
    {
        if ( defined $options->{box}{$_} ) { $options->{box}{$_}->hide_all; }
    }
    return;
}

sub get_paper_by_geometry {
    my ($self) = @_;
    my $formats = $self->get('paper-formats');
    if ( not defined $formats ) { return }
    my $options = $self->get('available-scan-options');
    my %current;
    for (qw(l t x y)) {
        $current{$_} = $options->by_name($_)->{val};
    }
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

# Update the sane option in the thread
# If necessary, reload the options,
# and walking the options tree, update the widgets

sub set_option {
    my ( $self, $option, $val ) = @_;
    $option->{val} = $val;
    $self->update_widget( $option->{name}, $val );

    $self->add_to_current_scan_options( $option, $val );

    # Do we need to reload?
    my $reload_triggers = $self->get('reload-triggers');
    my $reload_flag;
    if ( defined $reload_triggers ) {
        if ( ref($reload_triggers) ne 'ARRAY' ) {
            $reload_triggers = [$reload_triggers];
        }

        for ( @{$reload_triggers} ) {
            if ( $_ eq $option->{name} or $_ eq $option->{title} ) {
                $reload_flag = TRUE;
                last;
            }
        }
    }
    if ($reload_flag) {

        # Try to reload from the cache
        $reload_flag = FALSE;
        my $cache_key = $EMPTY;
        if ( $self->get('cache-options') ) {
            $cache_key = $self->cache_key();

            my $cache = $self->get('options-cache');
            if ( defined $cache->{ $self->get('device') }{$cache_key} ) {
                $reload_flag = TRUE;
                my $options = Gscan2pdf::Scanner::Options->new_from_data(
                    $cache->{ $self->get('device') }{$cache_key} );
                $self->signal_emit( 'fetched-options-cache',
                    $self->get('device'), $cache_key );
                $logger->info($options);

                if ($options) { $self->patch_cache($options) }

                $self->signal_emit( 'finished-process', 'find_scan_options' );

                # Unset the profile unless we are actively setting it
                if ( not $self->{setting_profile} ) {
                    $self->set( 'profile', undef );
                    $self->signal_emit(
                        'changed-current-scan-options',
                        $self->get('current-scan-options')
                    );
                }

                $self->signal_emit( 'changed-scan-option', $option->{name},
                    $val );
                $self->signal_emit('reloaded-scan-options');
            }
        }

        # Reload from the scanner
        if ( not $reload_flag ) {
            my $pbar;
            my $hboxd = $self->{hboxd};
            Gscan2pdf::Frontend::CLI->find_scan_options(
                prefix   => $self->get('prefix'),
                frontend => $self->get('frontend'),
                device   => $self->get('device'),
                options  => $self->map_options( $self->{current_scan_options} ),
                started_callback => sub {

                    # Set up ProgressBar
                    $pbar = Gtk2::ProgressBar->new;
                    $pbar->set_pulse_step( $self->get('progress-pulse-step') );
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
                    $hboxd->show_all;
                    $logger->info($options);
                    if ( $self->get('cache-options') ) {
                        my $cache = $self->get('options-cache');

                        # We only store the array part of the options object as
                        # we have to recreate the object anyway when we retrieve
                        # it
                        my $clone = dclone( $options->{array} );

                        if ( defined $cache ) {
                            $cache->{ $self->get('device') }{$cache_key} =
                              $clone;
                        }
                        else {
                            $cache->{ $self->get('device') }{$cache_key} =
                              $clone;
                            $self->set( 'options-cache', $cache );
                        }
                        $self->signal_emit( 'changed-options-cache', $cache );
                    }
                    if ($options) { $self->update_options($options) }

                    $self->signal_emit( 'finished-process',
                        'find_scan_options' );

                    # Unset the profile unless we are actively setting it
                    if ( not $self->{setting_profile} ) {
                        $self->set( 'profile', undef );
                        $self->signal_emit(
                            'changed-current-scan-options',
                            $self->get('current-scan-options')
                        );
                    }

                    $self->signal_emit( 'changed-scan-option', $option->{name},
                        $val );
                    $self->signal_emit('reloaded-scan-options');
                },
                error_callback => sub {
                    my ($message) = @_;
                    $self->signal_emit( 'process-error', 'find_scan_options',
                        $message );
                    $pbar->destroy;
                    $logger->warn($message);
                },
            );
        }
    }
    else {

        # Unset the profile unless we are actively setting it
        if ( not $self->{setting_profile} ) {
            $self->set( 'profile', undef );
            $self->signal_emit(
                'changed-current-scan-options',
                $self->get('current-scan-options')
            );
        }

        $self->signal_emit( 'changed-scan-option', $option->{name}, $val );
    }
    return;
}

# If we are loading from the cache, then both the current options, and the
# widgets could be different

sub patch_cache {
    my ( $self, $options ) = @_;

    # for reasons I don't understand, without walking the
    # reference tree, parts of $self->{current_scan_options}
    # are undef
    Dumper( $self->{current_scan_options} );
    for my $hashref ( @{ $self->{current_scan_options} } ) {
        my ( $key, undef ) = each %{$hashref};
        my $updated_option =
          $self->get('available-scan-options')->by_name($key);
        if ( defined( $updated_option->{name} )
            and $updated_option->{name} ne $EMPTY )
        {
            my $opt = $options->by_name( $updated_option->{name} );
            $opt->{val} = $updated_option->{val};
        }
    }
    $self->update_options($options);
    return;
}

sub update_widget {    # FIXME: this is partly duplicated in Sane.pm
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
        Dumper($profile);
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
                my $l = $self->get_option_from_profile( 'l', $profile );
                if ( not defined $l ) {
                    $l =
                      $self->get_option_from_profile( SANE_NAME_SCAN_TL_X,
                        $profile );
                }
                if ( defined $l ) { $val -= $l }
                $profile->[$i] = { $name => $val };
            }
            when (SANE_NAME_SCAN_BR_Y) {
                $name = 'y';
                my $t = $self->get_option_from_profile( 't', $profile );
                if ( not defined $t ) {
                    $t =
                      $self->get_option_from_profile( SANE_NAME_SCAN_TL_Y,
                        $profile );
                }
                if ( defined $t ) { $val -= $t }
                $profile->[$i] = { $name => $val };
            }
        }
    }
    return;
}

# Remove paper size from options,
# change boolean values from TRUE and FALSE to yes and no
sub map_options {
    my ( $self, $old ) = @_;
    my $new;
    my $options = $self->get('available-scan-options');
    for ( @{$old} ) {

        # for reasons I don't understand, without walking the reference tree,
        # parts of $_ are undef
        Dumper($_);
        my ( $key, $val ) = each %{$_};
        if ( $key ne 'Paper size' ) {
            my $opt = $options->by_name($key);
            if ( defined( $opt->{type} ) and $opt->{type} == SANE_TYPE_BOOL ) {
                $val = $val ? 'yes' : 'no';
            }
            push @{$new}, { $key => $val };
        }
    }
    return $new;
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

    # As scanimage and scanadf rename the geometry options,
    # we have to map them back to the original names
    my $options = $self->{current_scan_options};
    $self->map_geometry_names($options);

    my $i = 1;
    Gscan2pdf::Frontend::CLI->scan_pages(
        device           => $self->get('device'),
        dir              => $self->get('dir'),
        format           => 'out%d.pnm',
        options          => $self->map_options($options),
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
        },
        new_page_callback => sub {
            my ( $path, $n ) = @_;
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
    Gscan2pdf::Frontend::CLI->cancel_scan;
    $logger->info('Cancelled scan');
    return;
}

1;

__END__
