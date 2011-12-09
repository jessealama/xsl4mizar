#!/usr/bin/perl -w

use strict;
use File::Basename qw(basename dirname);
use XML::LibXML;
use POSIX qw(floor ceil);

unless (scalar @ARGV == 1) {
  print 'Usage: minimal.pl ARTICLE', "\n";
  exit 1;
}

my $article = $ARGV[0];
my $article_basename = basename ($article, '.miz');
my $article_dirname = dirname ($article);
my $article_sans_extension = "${article_dirname}/${article_basename}";
my $article_miz = "${article_dirname}/${article_basename}.miz";
my $article_err = "${article_dirname}/${article_basename}.err";
my $article_eno = "${article_dirname}/${article_basename}.eno";
my $article_refx = "${article_dirname}/${article_basename}.refx";

foreach my $extension ('miz', 'refx', 'eno') {
  my $article_with_extension = "${article_dirname}/${article_basename}.${extension}";
  unless (-e $article_with_extension) {
    print 'Error: the .', $extension, ' file for the supplied article ', $article, ' does not exist at the expected location (', $article_with_extension, ').', "\n";
    exit 1;
  }
  unless (-r $article_with_extension) {
    print 'Error: the .', $extension, ' file for the supplied article ', $article, ' is not readable.', "\n";
    exit 1;
  }
}

sub min {
  my $a = shift;
  my $b = shift;
  if ($a < $b) {
    return $a;
  } else {
    return $b;
  }
}

sub max {
  my $a = shift;
  my $b = shift;
  if ($a < $b) {
    return $b;
  } else {
    return $a;
  }
}

# Theorems and schemes
my $parsed_ref = ParseRef ($article_refx);
PruneRefXML ('Scheme', 'esh', $article_sans_extension, $parsed_ref);
PruneRefXML ('Theorem', 'eth', $article_sans_extension, $parsed_ref);

# my @extensions_to_minimize = ('eno');
my @extensions_to_minimize = ('eno', 'erd', 'epr', 'dfs', 'eid', 'ecl');
my %extension_to_element_table = ('eno' => 'Notations',
                                  'erd' => 'ReductionRegistrations',
                                  'epr' => 'PropertyRegistration',
                                  'dfs' => 'Definientia',
                                  'eid' => 'IdentifyRegistrations',
                                  'ecl' => 'Registrations');

my $xml_parser = XML::LibXML->new ();
my $xml_doc = $xml_parser->parse_file ($article_eno);

my $aid;
if ($xml_doc->exists ('/Notations[@aid]')) {
  $aid = $xml_doc->findvalue ('/Notations/@aid')
} else {
  print 'Error: the patterns file at ', $article_eno, ' does not have a root Notations element with an aid attribute.', "\n";
  exit 1;
}

sub write_element_table {
  my @elements = @{shift ()};
  my %table = %{shift ()};
  my $path = shift;
  my $root_element_name = shift;
  my $new_doc = XML::LibXML::Document->createDocument ();
  my $root = $new_doc->createElement ($root_element_name);

  # DEBUG
  # warn 'There are ', scalar @elements, ' available; we will now print just ', scalar (keys %table), ' of them now to ', $path;
  $root->setAttribute ('aid', $aid);
  $root->appendText ("\n");
  foreach my $i (0 .. scalar @elements - 1) {
    if (defined $table{$i}) {
      my $element = $elements[$i];
      $root->appendChild ($element);
      $root->appendText ("\n");
    }
  }
  $new_doc->setDocumentElement ($root);
  $new_doc->toFile ($path);

}

sub verify {
  system ("verifier -q -s -l $article_miz > /dev/null 2>&1");
  if (-z $article_err) {
    return 1;
  } else {
    # DEBUG
    # print 'Verifier failed.  Contents of the err file:', "\n";
    # system ("cat $article_err");
    return 0;
  }
}

## only callable with .eth or .esh; $refs is an array pointer of three hashes returned by ParseRef
sub PruneRefXML
{
  my ($xml_elem, $file_ext, $basename, $refs_ref) = @_;

  if ($file_ext ne 'esh' && $file_ext ne 'eth') {
    print 'Error: PruneRefXML works only with .esh and .eth files, not ', $file_ext, ' files.', "\n";
    exit 1;
  }

  my $xitemfile = "$basename.$file_ext";

  if (! -e $xitemfile) {
    print "Nothing to trim for $xml_elem\n";
    return;
  }

  if (-e $xitemfile) {
    {
      open(XML, $xitemfile) or die "Unable to open an output filehandle for $xitemfile!";
      local $/; $_ = <XML>;
      close(XML);
    }
  }

  my @refs = @{$refs_ref};
  my ($schs, $ths, $defs) = @refs;
  my $res = 0;

  my ($xmlbeg,$xmlnodes,$xmlend) = $_ =~ m/(.*?)([<]$xml_elem\b.*[<]\/$xml_elem>)(.*)/s;
  if (defined $xmlbeg) {

    my @xmlelems = $xmlnodes =~ m/(<$xml_elem\b.*?<\/$xml_elem>)/sg; # this is a multiline match

    open(XML1, '>', $xitemfile) or die "Unable to open an output filehandle for $xitemfile: $!";
    print XML1 $xmlbeg;

    if ($file_ext eq 'eth') {
      foreach my $elemnr (0 .. scalar(@xmlelems)-1) {
        my $first_line = (split /\n/, $xmlelems[$elemnr] )[0];

        $first_line =~ m/.*articlenr=\"(\d+)\".* nr=\"(\d+)\".* kind=\"([DT])\"/ or die "bad element $first_line";

        my ($ref, $kind) = ( "$1:$2", $3);
        my $needed = ($kind eq 'T')? $ths : $defs;

        if ( exists $needed->{$ref}) {
          print XML1 $xmlelems[$elemnr];
          $res++;
        }
      }
    }

    if ($file_ext eq 'esh') {
      foreach my $elemnr (0 .. scalar(@xmlelems)-1) {
        my $first_line = (split /\n/, $xmlelems[$elemnr] )[0];
        $first_line =~ m/.*articlenr=\"(\d+)\".* nr=\"(\d+)\".*/ or die "bad element $first_line";

        if ( exists $schs->{"$1:$2"}) {
          print XML1 $xmlelems[$elemnr];
          $res++;
        }
      }
    }

    print XML1 $xmlend;
    close(XML1);
    return $res;
  }
}

## return three hash pointers - first for schemes, then theorems, then definitions
sub ParseRef
  {
    my ($refx) = @_;
    open(REF,'<', "$refx") or die "Unable to open an input filehandle for $refx: $!";
    my @refs = ({},{},{});
    my $i = 0;
    while(<REF>)
      {
        if(/syThreeDots/)
          {
            $_ = <REF>;
            $_ =~ /x=\"(\d+)\"/ or die "bad REFX file";
            my $articlenr = $1;
            $_ = <REF>;
            $_ =~ /x=\"(\d+)\"/ or die "bad REFX file";
            my $refnr = $1;
            <REF>; <REF>;
            $refs[$i]->{"$articlenr:$refnr"} = 0;
          }
        if(/sySemiColon/)
          {
            $i++;
          }
    }
    close(REF);
    die "Wrong number of ref kinds: $i" if($i != 3);

    # DEBUG
    # foreach my $i (0 .. 2) {
    #  my %hash = %{$refs[$i]};
      # warn "ParseRef: hash number $i";
      # foreach my $key (keys (%hash)) {
        # warn "key: $key, value ", $hash{$key};
    #   }
    # }

    return \@refs;
}

sub print_element {
  my $element = shift;
  my $aid = $element->findvalue ('@aid');
  my $kind = $element->findvalue ('@kind');
  my $nr = $element->findvalue ('@nr');
  print $aid, ':', $kind, ':', $nr, "\n";
  return;
}

sub minimize {
  my @elements = @{shift ()};
  my %table = %{shift ()};
  my $path = shift;
  my $root_element_name = shift;
  my $begin = shift;
  my $end = shift;
  # DEBUG
  # print 'begin = ', $begin, ' and end = ', $end, "\n";
  if ($end < $begin) {
    return \%table;
  } elsif ($end == $begin) {
    # Try deleting
    delete $table{$begin};
    write_element_table (\@elements, \%table, $path, $root_element_name);
    my $deletable = verify ();
    if ($deletable == 1) {
      # print 'We can dump element #', $begin, "\n";
    } else {
      # print 'We cannot dump element #', $begin, "\n";
      $table{$begin} = 0;
      write_element_table (\@elements, \%table, $path, $root_element_name);
    }
    return \%table;
  } elsif ($begin + 1 == $end) {

    delete $table{$begin};
    write_element_table (\@elements, \%table, $path, $root_element_name);
    my $begin_deletable = verify ();

    if ($begin_deletable == 1) {
      # print 'We can dump element #', $begin, "\n";
    } else {
      # print 'We cannot dump element #', $begin, "\n";
      $table{$begin} = 0;
      write_element_table (\@elements, \%table, $path, $root_element_name);
    }

    delete $table{$end};
    write_element_table (\@elements, \%table, $path, $root_element_name);
    my $end_deletable = verify ();
    if ($end_deletable == 1) {
      # print 'We can dump element #', $end, "\n";
    } else {
      # print 'We cannot dump element #', $end, "\n";
      $table{$end} = 0;
      write_element_table (\@elements, \%table, $path, $root_element_name);
    }

    return \%table;

  } else {

    my $segment_length = $end - $begin + 1;
    my $half_segment_length = floor ($segment_length / 2);

    # Dump the lower half
    foreach my $i ($begin .. $begin + $half_segment_length) {
      delete $table{$i};
    }

    # Write this to disk
    write_element_table (\@elements, \%table, $path, $root_element_name);

    # Check that deleting the lower half is safe
    my $lower_half_safe = verify ();
    if ($lower_half_safe == 1) {
      # sleep 3;
      return (minimize (\@elements, \%table, $path, $root_element_name, $begin + $half_segment_length + 1, $end));
    } else {
      # Restore the lower half
      foreach my $i ($begin .. $begin + $half_segment_length) {
        $table{$i} = 0;
      }
      write_element_table (\@elements, \%table, $path, $root_element_name);
      # Minimize just the lower half
      # sleep 3;
      my %table_for_lower_half
        = %{minimize (\@elements, \%table, $path, $root_element_name, $begin, $begin + $half_segment_length)};
      # sleep 3;
      return (minimize (\@elements, \%table_for_lower_half, $path, $root_element_name, $begin + $half_segment_length + 1, $end));
    }
  }
}

foreach my $extension_to_minimize (@extensions_to_minimize) {
  my $root_element_name = $extension_to_element_table{$extension_to_minimize};
  if (defined $root_element_name) {
    my $article_with_extension = "${article_dirname}/${article_basename}.${extension_to_minimize}";
    if (-e $article_with_extension) {
      my $xml_parser = XML::LibXML->new ();
      my $xml_doc = $xml_parser->parse_file ($article_with_extension);
      my @elements = $xml_doc->findnodes ("/${root_element_name}/*");
      my %initial_table = ();
      foreach my $i (0 .. scalar @elements - 1) {
        $initial_table{$i} = 0;
      }
      print 'Minimizing ', $extension_to_minimize, '...';
      my %minimized_table
        = %{minimize (\@elements, \%initial_table, $article_with_extension, $root_element_name, 0, scalar @elements - 1)};
      print 'done.  The initial environment contained ', scalar @elements, ' elements, but we actually need only ', scalar keys %minimized_table, "\n";
    } else {
      print 'The .', $extension_to_minimize, ' file for ', $article_basename, ' does not exist; nothing to minimize.', "\n";
    }
  } else {
    print 'Error: we do not know how to deal with the ', $extension_to_minimize, ' files.', "\n";
    exit 1;
  }
}
