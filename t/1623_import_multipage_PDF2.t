use warnings;
use strict;
use File::Temp;
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
}

#########################

SKIP: {
    skip 'pdfunite (poppler utils) not installed', 2 unless `which pdfunite`;

    Gscan2pdf::Translation::set_domain('gscan2pdf');
    use Log::Log4perl qw(:easy);

    Log::Log4perl->easy_init($WARN);
    my $logger = Log::Log4perl::get_logger;
    Gscan2pdf::Document->setup($logger);

    # Create test image
    system('convert rose: page1.pdf');
    my $content = <<'EOS';
%PDF-1.4
1 0 obj
  << /Type /Catalog
      /Outlines 2 0 R
      /Pages 3 0 R
  >>
endobj

2 0 obj
  << /Type /Outlines
      /Count 0
  >>
endobj

3 0 obj
  << /Type /Pages
      /Kids [ 4 0 R ]
      /Count 1
  >>
endobj

4 0 obj
  << /Type /Page
      /Parent 3 0 R
      /MediaBox [ 0 0 612 792 ]
      /Contents 7 0 R
      /Resources 5 0 R
  >>
endobj

5 0 obj
  << /Font <</F1 6 0 R >> >>
endobj

6 0 obj
  << /Type /Font
      /Subtype /Type1
      /Name /F1
      /BaseFont /Courier
  >>
endobj

7 0 obj
  << /Length 62 >>
stream
  BT
    /F1 24 Tf
    100 100 Td
    ( Hello World ) Tj
  ET
endstream
endobj
xref
0 8
0000000000 65535 f 
0000000009 00000 n 
0000000091 00000 n 
0000000148 00000 n 
0000000224 00000 n 
0000000359 00000 n 
0000000404 00000 n 
0000000505 00000 n 
trailer
<</Size 8/Root 1 0 R>> 
startxref
618
%%EOF
EOS
    open my $fh, '>', 'page2.pdf' or die 'Cannot open page2.pdf';
    print $fh $content;
    close $fh;
    system('pdfunite page1.pdf page2.pdf test.pdf');

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);

    $slist->import_files(
        paths          => ['test.pdf'],
        error_callback => sub {
            my ($message) = @_;
            like $message, qr/one image per page/, 'one image per page warning';
        },
        finished_callback => sub {
            is( $#{ $slist->{data} }, 0, 'imported 1 image' );
            Gtk3->main_quit;
        }
    );
    Gtk3->main;

#########################

    unlink 'page1.pdf', 'page2.pdf', 'test.pdf', <$dir/*>;
    rmdir $dir;

    Gscan2pdf::Document->quit();
}
