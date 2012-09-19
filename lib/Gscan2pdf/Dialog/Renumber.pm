package Gscan2pdf::Dialog::Renumber;

use strict;
use warnings;
use Gscan2pdf::Dialog;
use Gscan2pdf::Document;

BEGIN {
 use Exporter ();
 our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

 use base qw(Exporter Gscan2pdf::Dialog);
 %EXPORT_TAGS = ();    # eg: TAG => [ qw!name1 name2! ],

 # your exported package globals go here,
 # as well as any optionally exported functions
 @EXPORT_OK = qw();
}
our @EXPORT_OK;

my $start = 1;
my $step  = 1;
my ( $spin_buttons, $spin_buttoni, $d, $slist, $page_range );

sub new {
 ( my $class, $d, $slist, $page_range ) = @_;
 my $self = Gscan2pdf::Dialog->new(
  'transient-for'  => $window,
  title            => $d->get('Renumber'),
  'hide-on-delete' => FALSE,
  border_width     => $border_width
 );
 my $vbox = $self->get('vbox');

 # Frame for page range
 my $frame = Gtk2::Frame->new( $d->get('Page Range') );
 $vbox->pack_start( $frame, FALSE, FALSE, 0 );
 my $pr = Gscan2pdf::PageRange->new;
 $pr->set_active($page_range)
   if ( defined $page_range );
 $pr->signal_connect(
  changed => sub {
   $page_range = $pr->get_active;
   update_renumber() if ( $page_range eq 'selected' );
  }
 );
 $frame->add($pr);
 push @prlist, $pr;

 # Frame for page numbering
 my $framex = Gtk2::Frame->new( $d->get('Page numbering') );
 $vbox->pack_start( $framex, FALSE, FALSE, 0 );
 my $vboxx = Gtk2::VBox->new;
 $vboxx->set_border_width($border_width);
 $framex->add($vboxx);

 # SpinButton for starting page number
 my $hboxxs = Gtk2::HBox->new;
 $vboxx->pack_start( $hboxxs, FALSE, FALSE, 0 );
 my $labelxs = Gtk2::Label->new( $d->get('Start') );
 $hboxxs->pack_start( $labelxs, FALSE, FALSE, 0 );
 $spin_buttons = Gtk2::SpinButton->new_with_range( 1, 99999, 1 );
 $hboxxs->pack_end( $spin_buttons, FALSE, FALSE, 0 );

 # SpinButton for page number increment
 my $hboxi = Gtk2::HBox->new;
 $vboxx->pack_start( $hboxi, FALSE, FALSE, 0 );
 my $labelxi = Gtk2::Label->new( $d->get('Increment') );
 $hboxi->pack_start( $labelxi, FALSE, FALSE, 0 );
 $spin_buttoni = Gtk2::SpinButton->new_with_range( -99, 99, 1 );
 $hboxi->pack_end( $spin_buttoni, FALSE, FALSE, 0 );

 $start = 1 unless ( defined $start );
 $step  = 1 unless ( defined $step );
 $spin_buttons->set_value($start);
 $spin_buttoni->set_value($step);

 # Check whether the settings are possible
 $spin_buttoni->signal_connect( 'value-changed' => \&update_renumber );
 $spin_buttons->signal_connect( 'value-changed' => \&update_renumber );
 update_renumber();

 # HBox for buttons
 my $hbox = Gtk2::HBox->new;
 $vbox->pack_start( $hbox, FALSE, TRUE, 0 );

 # Start button
 my $obutton = Gtk2::Button->new( $d->get('Renumber') );
 $hbox->pack_start( $obutton, TRUE, TRUE, 0 );
 $obutton->signal_connect(
  clicked => sub {
   if ( $slist->valid_renumber( $start, $step, $page_range ) ) {

    # Update undo/redo buffers
    take_snapshot();
    $slist->get_model->signal_handler_block( $slist->{row_changed_signal} );
    $slist->renumber( $start, $step, $page_range );

    # Note selection before sorting
    my @page = $slist->get_selected_indices;

    # Convert to page numbers
    for (@page) {
     $_ = $slist->{data}[$_][0];
    }

# Block selection_changed_signal to prevent its firing changing pagerange to all
    $slist->get_selection->signal_handler_block(
     $slist->{selection_changed_signal} );

    # Select new page, deselecting others. This fires the select callback,
    # displaying the page
    $slist->get_selection->unselect_all;
    $slist->manual_sort_by_column(0);
    $slist->get_selection->signal_handler_unblock(
     $slist->{selection_changed_signal} );
    $slist->get_model->signal_handler_unblock( $slist->{row_changed_signal} );

    # Convert back to indices
    for (@page) {

     # Due to the sort, must search for new page
     my $page = 0;
     ++$page
       while ( $page < $#{ $slist->{data} }
      and $slist->{data}[$page][0] != $_ );
     $_ = $page;
    }

    # Reselect pages
    $slist->select(@page);
   }
   else {
    show_message_dialog(
     $windowo, 'error', 'close',
     $d->get(
'The current settings would result in duplicate page numbers. Please select new start and increment values.'
     )
    );
   }
  }
 );

 # Close button
 my $cbutton = Gtk2::Button->new_from_stock('gtk-close');
 $hbox->pack_end( $cbutton, FALSE, FALSE, 0 );
 $cbutton->signal_connect( clicked => sub { $self->hide; } );

 bless( $self, $class );
 return $self;
}

# Helper function to prevent impossible settings in renumber dialog

sub update_renumber {
 my $start_old = $start;
 my $step_old  = $step;

 $start = $spin_buttons->get_value;
 $step  = $spin_buttoni->get_value;

 my $dstart = $start - $start_old;
 my $dstep  = $step_new - $step;
 if ( $dstart == 0 and $dstep == 0 ) {
  $dstart = 1;
  $dstep  = 1;
 }

 # Check for clash with non_selected
 while ( not $slist->valid_renumber( $start, $step, $page_range ) ) {
  if ( $current->min < 1 ) {
   if ( $dstart < 0 ) {
    $dstart = 1;
   }
   else {
    $dstep = 1;
   }
  }
  $start_new += $dstart;
  $step_new  += $dstep;
  $step_new  += $dstep if ( $step_new == 0 );
 }

 $spin_buttons->set_value($start_new);
 $spin_buttoni->set_value($step_new);
 $start = $start_new;
 $step  = $step_new;
 return;
}
