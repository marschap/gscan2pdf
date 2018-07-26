package Gscan2pdf::Dialog;

use warnings;
use strict;
use Gtk3;
use Glib 1.220 qw(TRUE FALSE);      # To get TRUE and FALSE
use Gscan2pdf::Document;
use Gscan2pdf::EntryCompletion;
use Gscan2pdf::Translation '__';    # easier to extract strings with xgettext
use Date::Calc qw(Add_Delta_Days Today);
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Readonly;
Readonly my $ENTRY_WIDTH_DATE     => 10;
Readonly my $ENTRY_WIDTH_DATETIME => 19;

use Glib::Object::Subclass Gtk3::Window::,
  signals => {
    delete_event    => \&on_delete_event,
    key_press_event => \&on_key_press_event,
  },
  properties => [
    Glib::ParamSpec->uint(
        'border-width',             # name
        'Border width',             # nickname
        'Border width for vbox',    # blurb
        0,                          # min
        999,                        # max
        0,                          # default
        [qw/readable writable/]     # flags
    ),
    Glib::ParamSpec->boolean(
        'hide-on-delete',                                             # name
        'Hide on delete',                                             # nickname
        'Whether to destroy or hide the dialog when it is dismissed', # blurb
        FALSE,                                                        # default
        [qw/readable writable/]                                       # flags
    ),
    Glib::ParamSpec->object(
        'vbox',                                                       # name
        'VBox',                                                       # nickname
        'VBox which is automatically added to the Gscan2pdf::Dialog', # blurb
        'Gtk3::VBox',                                                 # package
        [qw/readable writable/]                                       # flags
    ),
    Glib::ParamSpec->boolean(
        'include-time',                                               # name
        'Specify the time as well as date',                           # nickname
        'Whether to allow the time, as well as the date, to be entered', # blurb
        FALSE,                     # default
        [qw/readable writable/]    # flags
    ),
  ];

our $VERSION = '2.1.2';
my $EMPTY    = q{};
my $HEXREGEX = qr{^(.*)           # start of message
                  \b0x[[:xdigit:]]+\b # hex (e.g. address)
                  (.*)$           # rest of message
                 }xsm;
my $INTREGEX = qr{^(.*)           # start of message
                  \b[[:digit:]]+\b # integer
                  (.*)$           # rest of message
                 }xsm;
my $DATE_FORMAT     = '%04d-%02d-%02d';
my $DATETIME_FORMAT = '%04d-%02d-%02d %02d:%02d:%02d';

sub INIT_INSTANCE {
    my $self = shift;

    $self->set_position('center-on-parent');

    # VBox for window
    my $vbox = Gtk3::VBox->new;
    $self->add($vbox);
    $self->set( 'vbox', $vbox );
    return $self;
}

sub SET_PROPERTY {
    my ( $self, $pspec, $newval ) = @_;
    my $name = $pspec->get_name;
    $self->{$name} = $newval;
    if ( $name eq 'border_width' ) {
        $self->get('vbox')->set( 'border-width', $newval );
    }
    elsif ( $name eq 'include_time' ) {
        $self->on_toggle_include_time($newval);
    }
    return;
}

sub on_delete_event {
    my ( $widget, $event ) = @_;
    if ( $widget->get('hide-on-delete') ) {
        $widget->hide;
        return Gtk3::EVENT_STOP;    # ensures that the window is not destroyed
    }
    $widget->destroy;
    return Gtk3::EVENT_PROPAGATE;
}

sub on_key_press_event {
    my ( $widget, $event ) = @_;
    if ( $event->keyval != Gtk3::Gdk::KEY_Escape ) {
        $widget->signal_chain_from_overridden($event);
        return Gtk3::EVENT_PROPAGATE;
    }
    if ( $widget->get('hide-on-delete') ) {
        $widget->hide;
    }
    else {
        $widget->destroy;
    }
    return Gtk3::EVENT_STOP;
}

sub on_toggle_include_time {
    my ( $self, $newval ) = @_;
    if ( defined $self->{mdwidgets} ) {
        if ($newval) {
            $self->{mdwidgets}{button_now}->get_child->set_text( __('Now') );
            $self->{mdwidgets}{button_now}
              ->set_tooltip_text( __('Use current date and time') );
            $self->{mdwidgets}{date}->set_max_length($ENTRY_WIDTH_DATETIME);
            $self->{mdwidgets}{date}
              ->set_text( $self->{mdwidgets}{date}->get_text . ' 00:00:00' );
        }
        else {
            $self->{mdwidgets}{button_now}->get_child->set_text( __('Today') );
            $self->{mdwidgets}{button_now}
              ->set_tooltip_text( __("Use today's date") );
            $self->{mdwidgets}{date}->set_max_length($ENTRY_WIDTH_DATE);
        }
    }
    return;
}

sub on_clicked_specify_datetime {
    my ( $widget, $self ) = @_;
    if ( $self->{mdwidgets}{button_specify_dt}->get_active ) {
        $self->{mdwidgets}{datetime_box}->show;
    }
    else {
        $self->{mdwidgets}{datetime_box}->hide;
    }
    return;
}

sub add_metadata {
    my ( $self, $defaults ) = @_;
    my ($vbox) = $self->get('vbox');

    # it needs its own box to be able to hide it if necessary
    my $hboxmd = Gtk3::HBox->new;
    $vbox->pack_start( $hboxmd, FALSE, FALSE, 0 );

    # Frame for metadata
    my $frame = Gtk3::Frame->new( __('Document Metadata') );
    $hboxmd->pack_start( $frame, TRUE, TRUE, 0 );
    my $hboxm = Gtk3::VBox->new;
    $hboxm->set_border_width( $self->get('border-width') );
    $frame->add($hboxm);

    # grid to align widgets
    my $grid = Gtk3::Grid->new;
    my $row  = 0;
    $hboxm->pack_start( $grid, TRUE, TRUE, 0 );

    # Date/time
    my $dtframe = Gtk3::Frame->new( __('Date/Time') );
    $grid->attach( $dtframe, 0, $row++, 2, 1 );
    $dtframe->set_hexpand(TRUE);
    my $vboxdt = Gtk3::VBox->new;
    $vboxdt->set_border_width( $self->get('border-width') );
    $dtframe->add($vboxdt);

    # the first radio button has to set the group,
    # which is undef for the first button
    # Now button
    my $bnow = Gtk3::RadioButton->new_with_label( undef, __('Now') );
    $bnow->set_tooltip_text( __('Use current date and time') );
    $vboxdt->pack_start( $bnow, TRUE, TRUE, 0 );

    # Specify button
    my $bspecify_dt =
      Gtk3::RadioButton->new_with_label_from_widget( $bnow, __('Specify') );
    $bspecify_dt->set_tooltip_text( __('Specify date and time') );
    $vboxdt->pack_start( $bspecify_dt, TRUE, TRUE, 0 );

    $bspecify_dt->signal_connect(
        clicked => \&on_clicked_specify_datetime,
        $self
    );

    my $entryd        = Gtk3::Entry->new;
    my @today_and_now = Add_Delta_Days( @{ $defaults->{date}{today} },
        $defaults->{date}{offset} );
    if ( defined $defaults->{date}{time} ) {
        push @today_and_now, @{ $defaults->{date}{time} };
    }
    $entryd->set_text(
        Gscan2pdf::Document::expand_metadata_pattern(
            template => defined $defaults->{date}{time}
            ? '%Y-%m-%d %H:%M:%S'
            : '%Y-%m-%d',
            today_and_now => \@today_and_now,
        )
    );
    $entryd->set_activates_default(TRUE);
    $entryd->set_tooltip_text( __('Year-Month-Day') );
    $entryd->set_alignment(1.);    # Right justify
    $entryd->signal_connect( 'insert-text' => \&insert_text_handler, $self );
    $entryd->signal_connect(
        'focus-out-event' => sub {
            my $text = $entryd->get_text;
            if ( defined $text and $text ne $EMPTY ) {
                if ( $self->get('include-time') ) {
                    $text = sprintf $DATETIME_FORMAT,
                      Gscan2pdf::Document::text_to_datetime($text);
                }
                else {
                    $text = sprintf $DATE_FORMAT,
                      Gscan2pdf::Document::text_to_datetime($text);
                }
                $entryd->set_text($text);
            }
            return FALSE;
        }
    );
    my $button = Gtk3::Button->new;
    $button->set_image( Gtk3::Image->new_from_stock( 'gtk-edit', 'button' ) );
    $button->signal_connect(
        clicked => sub {
            my $window_date = Gscan2pdf::Dialog->new(
                'transient-for' => $self,
                title           => __('Select Date'),
                border_width    => $self->get('border-width')
            );
            my $vbox_date = $window_date->get('vbox');
            $window_date->set_resizable(FALSE);
            my $calendar = Gtk3::Calendar->new;

            # Editing the entry and clicking the edit button bypasses the
            # focus-out-event, so update the date now
            my ( $year, $month, $day, $hour, $min, $sec ) =
              Gscan2pdf::Document::text_to_datetime( $entryd->get_text );

            $calendar->select_day($day);
            $calendar->select_month( $month - 1, $year );
            my $calendar_s;
            $calendar_s = $calendar->signal_connect(
                day_selected => sub {
                    ( $year, $month, $day ) = $calendar->get_date;
                    $month += 1;
                    $entryd->set_text( sprintf $DATETIME_FORMAT,
                        $year, $month, $day, $hour, $min, $sec );
                }
            );
            $calendar->signal_connect(
                day_selected_double_click => sub {
                    ( $year, $month, $day ) = $calendar->get_date;
                    $month += 1;
                    $entryd->set_text( sprintf $DATETIME_FORMAT,
                        $year, $month, $day, $hour, $min, $sec );
                    $window_date->destroy;
                }
            );
            $vbox_date->pack_start( $calendar, TRUE, TRUE, 0 );

            my $today = Gtk3::Button->new( __('Today') );
            $today->signal_connect(
                clicked => sub {
                    ( $year, $month, $day ) = Today();

                    # block and unblock signal, and update entry manually
                    # to remove possibility of race conditions
                    $calendar->signal_handler_block($calendar_s);
                    $calendar->select_day($day);
                    $calendar->select_month( $month - 1, $year );
                    $calendar->signal_handler_unblock($calendar_s);
                    $entryd->set_text( sprintf $DATETIME_FORMAT,
                        $year, $month, $day, $hour, $min, $sec );
                }
            );
            $vbox_date->pack_start( $today, TRUE, TRUE, 0 );

            $window_date->show_all;
        }
    );
    $button->set_tooltip_text( __('Select date with calendar') );
    my $hboxe = Gtk3::HBox->new;
    $vboxdt->pack_start( $hboxe, TRUE, TRUE, 0 );
    $hboxe->pack_end( $button, FALSE, FALSE, 0 );
    $hboxe->pack_end( $entryd, FALSE, FALSE, 0 );

    # Don't show these widgets when the window is shown
    $hboxe->set_no_show_all(TRUE);
    $entryd->show;
    $button->show;

    my @label = (
        { title    => __('Title') },
        { author   => __('Author') },
        { subject  => __('Subject') },
        { keywords => __('Keywords') },
    );
    my %widgets = (
        box               => $hboxmd,
        datetime_box      => $hboxe,
        date              => $entryd,
        button_now        => $bnow,
        button_specify_dt => $bspecify_dt,
    );
    for my $entry (@label) {
        my ( $name, $label ) = %{$entry};
        my $hbox = Gtk3::HBox->new;
        $grid->attach( $hbox, 0, $row, 1, 1 );
        $label = Gtk3::Label->new($label);
        $hbox->pack_start( $label, FALSE, TRUE, 0 );
        $hbox = Gtk3::HBox->new;
        $grid->attach( $hbox, 1, $row++, 1, 1 );
        my $entry =
          Gscan2pdf::EntryCompletion->new( $defaults->{$name}{default},
            $defaults->{$name}{suggestions} );
        $hbox->pack_start( $entry, TRUE, TRUE, 0 );
        $widgets{$name} = $entry;
    }
    $self->{mdwidgets} = \%widgets;
    $self->on_toggle_include_time( $self->get('include-time') );
    on_clicked_specify_datetime( $bspecify_dt, $self );
    return;
}

sub insert_text_handler {
    my ( $widget, $string, $len, $position, $self ) = @_;

    # only allow integers and -
    if (
        ( not $self->get('include-time') and $string =~ /^[\d\-]+$/smx )
        or

        # only allow integers, space, : and -
        ( $self->get('include-time') and $string =~ /^[\d\- :]+$/smx )
      )
    {
        $widget->signal_handlers_block_by_func( \&insert_text_handler );
        $widget->insert_text( $string, $len, $position++ );
        $widget->signal_handlers_unblock_by_func( \&insert_text_handler );
    }
    $widget->signal_stop_emission_by_name('insert-text');
    return $position;
}

sub dump_or_stringify {
    my ($val) = @_;
    return (
        defined $val
        ? ( ref($val) eq $EMPTY ? $val : Dumper($val) )
        : 'undef'
    );
}

# External tools sometimes throws warning messages including a number,
# e.g. hex address. As the number is very rarely the same, although the message
# itself is, filter out the number from the message

sub filter_message {
    my ($message) = @_;
    while ( $message =~ /$HEXREGEX/xsmo ) {
        $message =~ s/$HEXREGEX/$1%%x$2/xsmo;
    }
    while ( $message =~ /$INTREGEX/xsmo ) {
        $message =~ s/$INTREGEX/$1%%d$2/xsmo;
    }
    return $message;
}

1;

__END__
