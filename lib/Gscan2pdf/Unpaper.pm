package Gscan2pdf::Unpaper;

use 5.008005;
use strict;
use warnings;
use feature 'switch';
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use Carp;
use Glib qw(TRUE FALSE);            # To get TRUE and FALSE
use Gtk3;
use version;
use Gscan2pdf::Document;
use Gscan2pdf::Translation '__';    # easier to extract strings with xgettext
use Readonly;
Readonly my $BORDER_WIDTH => 6;

BEGIN {
    use Exporter ();
    our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

    $VERSION = '2.0.0';

    use base qw(Exporter);
    %EXPORT_TAGS = ();              # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw();
}
our @EXPORT_OK;

my $COMMA = q{,};
my $SPACE = q{ };
my ($version);

sub new {
    my ( $class, $default ) = @_;
    my $self = {};
    $self->{default} = defined $default ? $default : {};

    # Set up hash for options
    $self->{options} = {
        layout => {
            type    => 'ComboBox',
            string  => __('Layout'),
            options => {
                single => {
                    string  => __('Single'),
                    tooltip => __(
                        'One page per sheet, oriented upwards without rotation.'
                    ),
                },
                double => {
                    string  => __('Double'),
                    tooltip => __(
'Two pages per sheet, landscape orientation (one page on the left half, one page on the right half).'
                    ),
                },
            },
            default => 'single',
        },
        'output-pages' => {
            type    => 'SpinButton',
            string  => __('# Output pages'),
            tooltip => __('Number of pages to output.'),
            min     => 1,
            max     => 2,
            step    => 1,
            default => 1,
        },
        'direction' => {
            type    => 'ComboBox',
            string  => __('Writing system'),
            options => {
                ltr => {
                    string  => __('Left-to-right'),
                    tooltip => __(
                        'Most writings systems, e.g. Latin, Greek, Cyrillic.'
                    ),
                },
                rtl => {
                    string  => __('Right-to-left'),
                    tooltip => __('Scripts like Arabic or Hebrew.'),
                },
            },
            default => 'ltr',
            export  => FALSE,
        },
        'no-deskew' => {
            type    => 'CheckButton',
            string  => __('No deskew'),
            tooltip => __('Disable deskewing.'),
            default => FALSE,
        },
        'no-mask-scan' => {
            type    => 'CheckButton',
            string  => __('No mask scan'),
            tooltip => __('Disable mask detection.'),
            default => FALSE,
        },
        'no-mask-center' => {
            type    => 'CheckButton',
            string  => __('No mask centering'),
            tooltip => __('Disable mask centering.'),
            default => FALSE,
        },
        'no-blackfilter' => {
            type    => 'CheckButton',
            string  => __('No black filter'),
            tooltip => __('Disable black area scan.'),
            default => FALSE,
        },
        'no-grayfilter' => {
            type    => 'CheckButton',
            string  => __('No gray filter'),
            tooltip => __('Disable gray area scan.'),
            default => FALSE,
        },
        'no-noisefilter' => {
            type    => 'CheckButton',
            string  => __('No noise filter'),
            tooltip => __('Disable noise filter.'),
            default => FALSE,
        },
        'no-blurfilter' => {
            type    => 'CheckButton',
            string  => __('No blur filter'),
            tooltip => __('Disable blur filter.'),
            default => FALSE,
        },
        'no-border-scan' => {
            type    => 'CheckButton',
            string  => __('No border scan'),
            tooltip => __('Disable border scanning.'),
            default => FALSE,
        },
        'no-border-align' => {
            type   => 'CheckButton',
            string => __('No border align'),
            tooltip =>
              __('Disable aligning of the area detected by border scanning.'),
            default => FALSE,
        },
        'deskew-scan-direction' => {
            type    => 'CheckButtonGroup',
            string  => __('Deskew to edge'),
            tooltip => __(
"Edges from which to scan for rotation. Each edge of a mask can be used to detect the mask's rotation. If multiple edges are specified, the average value will be used, unless the statistical deviation exceeds --deskew-scan-deviation."
            ),
            options => {
                left => {
                    type   => 'CheckButton',
                    string => __('Left'),
                    tooltip =>
                      __("Use 'left' for scanning from the left edge."),
                },
                top => {
                    type    => 'CheckButton',
                    string  => __('Top'),
                    tooltip => __("Use 'top' for scanning from the top edge."),
                },
                right => {
                    type   => 'CheckButton',
                    string => __('Right'),
                    tooltip =>
                      __("Use 'right' for scanning from the right edge."),
                },
                bottom => {
                    type    => 'CheckButton',
                    string  => __('Bottom'),
                    tooltip => __("Use 'bottom' for scanning from the bottom."),
                },
            },
            default => 'left,right',
        },
        'border-align' => {
            type    => 'CheckButtonGroup',
            string  => __('Align to edge'),
            tooltip => __('Edge to which to align the page.'),
            options => {
                left => {
                    type    => 'CheckButton',
                    string  => __('Left'),
                    tooltip => __("Use 'left' to align to the left edge."),
                },
                top => {
                    type    => 'CheckButton',
                    string  => __('Top'),
                    tooltip => __("Use 'top' to align to the top edge."),
                },
                right => {
                    type    => 'CheckButton',
                    string  => __('Right'),
                    tooltip => __("Use 'right' to align to the right edge."),
                },
                bottom => {
                    type    => 'CheckButton',
                    string  => __('Bottom'),
                    tooltip => __("Use 'bottom' to align to the bottom."),
                },
            },
        },
        'border-margin' => {
            type    => 'SpinButtonGroup',
            string  => __('Border margin'),
            options => {
                vertical => {
                    type    => 'SpinButton',
                    string  => __('Vertical margin'),
                    tooltip => __(
'Vertical distance to keep from the sheet edge when aligning a border area.'
                    ),
                    min   => 0,
                    max   => 1000,
                    step  => 1,
                    order => 0,
                },
                horizontal => {
                    type    => 'SpinButton',
                    string  => __('Horizontal margin'),
                    tooltip => __(
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
            string => __('White threshold'),
            tooltip =>
              __('Brightness ratio above which a pixel is considered white.'),
            min     => 0,
            max     => 1,
            step    => .01,
            default => 0.9,
        },
        'black-threshold' => {
            type    => 'SpinButton',
            string  => __('Black threshold'),
            tooltip => __(
'Brightness ratio below which a pixel is considered black (non-gray). This is used by the gray-filter. This value is also used when converting a grayscale image to black-and-white mode.'
            ),
            min     => 0,
            max     => 1,
            step    => .01,
            default => 0.33,
        },
    };
    bless $self, $class;
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
    my $combobw = $self->add_widget( $vbox, $options, 'direction' );
    $outpages->signal_connect(
        'value-changed' => sub {
            $combobw->get_parent->set_sensitive( $outpages->get_value == 2 );
        }
    );
    $combobw->get_parent->set_sensitive(FALSE);

    # Notebook to collate options
    my $notebook = Gtk3::Notebook->new;
    $vbox->pack_start( $notebook, TRUE, TRUE, 0 );

    # Notebook page 1
    my $vbox1 = Gtk3::VBox->new;
    $vbox1->set_border_width($BORDER_WIDTH);
    $notebook->append_page( $vbox1, Gtk3::Label->new( __('Deskew') ) );

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

    for ( keys %{ $options->{'deskew-scan-direction'}{options} } ) {
        my $button = $options->{'deskew-scan-direction'}{options}{$_}{widget};

        # Ensure that at least one checkbutton stays active
        $button->signal_connect(
            toggled => sub {
                if ( count_active_children($dframe) == 0 ) {
                    $button->set_active(TRUE);
                }
            }
        );
    }

    # Notebook page 2
    my $vbox2 = Gtk3::VBox->new;
    $vbox2->set_border_width($BORDER_WIDTH);
    $notebook->append_page( $vbox2, Gtk3::Label->new( __('Border') ) );

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
                if ( not $babutton->get_active ) {
                    $bframe->set_sensitive(TRUE);
                }
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

    for ( keys %{ $options->{'border-align'}{options} } ) {
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
    my $vbox3 = Gtk3::VBox->new;
    $vbox3->set_border_width($BORDER_WIDTH);
    $notebook->append_page( $vbox3, Gtk3::Label->new( __('Filters') ) );

    my $spinbuttonwt = $self->add_widget( $vbox3, $options, 'white-threshold' );
    my $spinbuttonbt = $self->add_widget( $vbox3, $options, 'black-threshold' );
    my $msbutton     = $self->add_widget( $vbox3, $options, 'no-mask-scan' );
    my $mcbutton     = $self->add_widget( $vbox3, $options, 'no-mask-center' );
    my $bfbutton     = $self->add_widget( $vbox3, $options, 'no-blackfilter' );
    my $gfbutton     = $self->add_widget( $vbox3, $options, 'no-grayfilter' );
    my $nfbutton     = $self->add_widget( $vbox3, $options, 'no-noisefilter' );
    my $blbutton     = $self->add_widget( $vbox3, $options, 'no-blurfilter' );

    # make no-mask-center depend on no-mask-scan
    $msbutton->signal_connect(
        toggled => sub {
            if ( $msbutton->get_active ) {
                $mcbutton->set_sensitive(FALSE);
            }
            else {
                $mcbutton->set_sensitive(TRUE);
            }
        }
    );

    # Having added the widgets with callbacks if necessary, set the defaults
    $self->set_options( $self->{default} );

    return;
}

sub count_active_children {
    my ($frame) = @_;
    my $n = 0;
    for ( $frame->get_child->get_children ) {
        if ( $_->get_active ) { $n++ }
    }
    return $n;
}

# Add widget to unpaper dialog

sub add_widget {
    my ( $self, $vbox, $hashref, $option ) = @_;
    my $default = $self->{default};
    my $widget;
    if ( defined( $hashref->{$option}{default} )
        and not defined( $default->{$option} ) )
    {
        $default->{$option} = $hashref->{$option}{default};
    }

    given ( $hashref->{$option}{type} ) {
        when ('ComboBox') {
            my $hbox = Gtk3::HBox->new;
            $vbox->pack_start( $hbox, TRUE, TRUE, 0 );
            my $label = Gtk3::Label->new( $hashref->{$option}{string} );
            $hbox->pack_start( $label, FALSE, FALSE, 0 );
            $widget = Gtk3::ComboBoxText->new;
            $hbox->pack_end( $widget, FALSE, FALSE, 0 );

            # Add text and tooltips
            my @tooltip;
            my $i = 0;
            for ( keys %{ $hashref->{$option}{options} } ) {
                $widget->append_text(
                    $hashref->{$option}{options}{$_}{string} );
                push @tooltip, $hashref->{$option}{options}{$_}{tooltip};
                $hashref->{$option}{options}{$_}{index} = $i++;
            }
            $widget->signal_connect(
                changed => sub {
                    if ( defined $tooltip[ $widget->get_active ] ) {
                        $widget->set_tooltip_text(
                            $tooltip[ $widget->get_active ] );
                    }
                }
            );
        }

        when ('CheckButton') {
            $widget = Gtk3::CheckButton->new( $hashref->{$option}{string} );
            $widget->set_tooltip_text( $hashref->{$option}{tooltip} );
            $vbox->pack_start( $widget, TRUE, TRUE, 0 );
        }

        when ('CheckButtonGroup') {
            $widget = Gtk3::Frame->new( $hashref->{$option}{string} );
            $vbox->pack_start( $widget, TRUE, TRUE, 0 );
            my $vboxf = Gtk3::VBox->new;
            $vboxf->set_border_width($BORDER_WIDTH);
            $widget->add($vboxf);
            $widget->set_tooltip_text( $hashref->{$option}{tooltip} );
            for ( keys %{ $hashref->{$option}{options} } ) {
                my $button =
                  $self->add_widget( $vboxf, $hashref->{$option}{options}, $_ );
            }
        }

        when ('SpinButton') {
            my $hbox = Gtk3::HBox->new;
            $vbox->pack_start( $hbox, TRUE, TRUE, 0 );
            my $label = Gtk3::Label->new( $hashref->{$option}{string} );
            $hbox->pack_start( $label, FALSE, FALSE, 0 );
            $widget = Gtk3::SpinButton->new_with_range(
                $hashref->{$option}{min},
                $hashref->{$option}{max},
                $hashref->{$option}{step}
            );
            $hbox->pack_end( $widget, FALSE, FALSE, 0 );
            $widget->set_tooltip_text( $hashref->{$option}{tooltip} );
            if ( defined $default->{$option} ) {
                $widget->set_value( $default->{$option} );
            }
        }

        when ('SpinButtonGroup') {
            $widget = Gtk3::Frame->new( $hashref->{$option}{string} );
            $vbox->pack_start( $widget, TRUE, TRUE, 0 );
            my $vboxf = Gtk3::VBox->new;
            $vboxf->set_border_width($BORDER_WIDTH);
            $widget->add($vboxf);
            for (
                sort {
                    $hashref->{$option}{options}{$a}{order}
                      <=> $hashref->{$option}{options}{$b}{order}
                } keys %{ $hashref->{$option}{options} }
              )
            {
                my $button =
                  $self->add_widget( $vboxf, $hashref->{$option}{options}, $_ );
            }
        }
    }

    $hashref->{$option}{widget} = $widget;
    return $widget;
}

sub get_option {
    my ( $self, $option ) = @_;
    my $hashref = $self->{options};
    my $default = $self->{default};

    if ( defined $hashref->{$option}{widget} ) {

        given ( $hashref->{$option}{type} ) {
            when ('ComboBox') {
                my $i = $hashref->{$option}{widget}->get_active;
                for ( keys %{ $hashref->{$option}{options} } ) {
                    if ( $hashref->{$option}{options}{$_}{index} == $i ) {
                        return $_;
                    }
                }
            }
            when ('CheckButton') {
                return $hashref->{$option}{widget}->get_active ? TRUE : FALSE;
            }
            when ('SpinButton') {
                return $hashref->{$option}{widget}->get_value;
            }
            when ('CheckButtonGroup') {
                my @items;
                for ( sort keys %{ $hashref->{$option}{options} } ) {
                    if ( $hashref->{$option}{options}{$_}{widget}->get_active )
                    {
                        push @items, $_;
                    }
                }
                if (@items) { return join $COMMA, @items }
            }
            when ('SpinButtonGroup') {
                my @items;
                for ( keys %{ $hashref->{$option}{options} } ) {
                    push @items,
                      $hashref->{$option}{options}{$_}{widget}->get_value;
                }
                if (@items) { return join $COMMA, @items }
            }
        }
    }
    elsif ( defined $default->{$option} ) { return $default->{$option} }
    elsif ( defined $hashref->{$option} ) {
        return $hashref->{$option}{default};
    }
    return;
}

sub get_options {
    my ($self)  = @_;
    my $hashref = $self->{options};
    my $default = $self->{default};

    for my $option ( keys %{$hashref} ) {
        my $value = $self->get_option($option);
        if ( defined $value ) { $default->{$option} = $value }
    }
    return $default;
}

sub set_options {
    my ( $self, $options ) = @_;
    my $hashref = $self->{options};

    for my $option ( keys %{$options} ) {
        if ( defined $hashref->{$option}{widget} ) {
            given ( $hashref->{$option}{type} ) {
                when ('ComboBox') {
                    my $i = $hashref->{$option}{options}{ $options->{$option} }
                      {index};
                    if ( defined $i ) {
                        $hashref->{$option}{widget}->set_active($i);
                    }
                }
                when ('CheckButton') {
                    $hashref->{$option}{widget}
                      ->set_active( $options->{$option} );
                }
                when ('CheckButtonGroup') {
                    my %default;
                    if ( defined $options->{$option} ) {
                        for ( split /,/sm, $options->{$option} ) {
                            $default{$_} = TRUE;
                        }
                    }
                    for ( keys %{ $hashref->{$option}{options} } ) {
                        $hashref->{$option}{options}{$_}{widget}
                          ->set_active( defined $default{$_} );
                    }
                }
                when ('SpinButton') {
                    $hashref->{$option}{widget}
                      ->set_value( $options->{$option} );
                }
                when ('SpinButtonGroup') {
                    my @default;
                    if ( defined $options->{$option} ) {
                        @default = split /,/sm, $options->{$option};
                    }
                    for (
                        sort {
                            $hashref->{$option}{options}{$a}{order}
                              <=> $hashref->{$option}{options}{$b}{order}
                        } keys %{ $hashref->{$option}{options} }
                      )
                    {
                        if (@default) {
                            $hashref->{$option}{options}{$_}{widget}
                              ->set_value( shift @default );
                        }
                    }
                }
            }
        }
    }
    return;
}

sub get_cmdline {
    my ($self)  = @_;
    my $hashref = $self->{options};
    my $default = $self->get_options;

    my @items;
    for my $option ( sort keys %{$hashref} ) {
        if ( defined $hashref->{$option}{export}
            and not $hashref->{$option}{export} )
        {
            next;
        }
        if ( $hashref->{$option}{type} eq 'CheckButton' ) {
            if ( defined $default->{$option} and $default->{$option} ) {
                push @items, "--$option";
            }
        }
        else {
            if ( defined $default->{$option} ) {
                push @items, "--$option $default->{$option}";
            }
        }
    }
    my $cmd = 'unpaper ' . join( $SPACE, @items ) . ' --overwrite ';
    $cmd .=
      version->parse( 'v' . $self->version ) > version->parse('v0.3')
      ? '%s %s %s'
      : '--input-file-sequence %s --output-file-sequence %s %s';
    return $cmd;
}

sub version {
    if ( not defined $version ) {
        $version =
          Gscan2pdf::Document::program_version( 'stdout', qr/([\d.]+)/xsm,
            [ 'unpaper', '--version' ] );
    }
    return $version;
}

1;

__END__
