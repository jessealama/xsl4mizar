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
my $article_esh = "${article_dirname}/${article_basename}.esh";
my $article_eth = "${article_dirname}/${article_basename}.eth";

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

sub prune_theorems {
  my $refx_parser = XML::LibXML->new ();
  my $refx_doc = $refx_parser->parse_file ($article_refx);
  my %theorems = ();
  my %definitions = ();

  my @middle_sy_three_dots = $refx_doc->findnodes ('Parser/syThreeDots[preceding-sibling::sySemiColon and following-sibling::sySemiColon[2]]');
  # DEBUG
  # print 'In the middle sySemiColon segment, there are ', scalar @middle_sy_three_dots, ' syThreeDots elements.', "\n";
  foreach my $sy_three_dots (@middle_sy_three_dots) {
    my $aid = $sy_three_dots->findvalue ('following-sibling::Int[1]/@x');
    my $nr = $sy_three_dots->findvalue ('following-sibling::Int[2]/@x');
    unless (defined $aid && defined $nr) {
      print 'Error: we failed to extract either the first or the second Int following an syThreeDots element!', "\n";
      exit 1;
    }
    $theorems{"$aid:$nr"} = 0;
  }
  my @final_sy_three_dots = $refx_doc->findnodes ('Parser/syThreeDots[preceding-sibling::sySemiColon and following-sibling::sySemiColon[1] and not(following-sibling::sySemiColon[2])]');
  # DEBUG
  # print 'In the final sySemiColon segment, there are ', scalar @final_sy_three_dots, ' syThreeDots elements.', "\n";
  foreach my $sy_three_dots (@final_sy_three_dots) {
    my $aid = $sy_three_dots->findvalue ('following-sibling::Int[1]/@x');
    my $nr = $sy_three_dots->findvalue ('following-sibling::Int[2]/@x');
    unless (defined $aid && defined $nr) {
      print 'Error: we failed to extract either the first or the second Int following an syThreeDots element!', "\n";
      exit 1;
    }
    $definitions{"$aid:$nr"} = 0;
  }

  if (-e $article_eth) {
    print 'Minimizing eth...';
    my $eth_parser = XML::LibXML->new ();
    my $eth_doc = $eth_parser->parse_file ($article_eth);

    # Create the new .eth document
    my $new_eth_doc = XML::LibXML::Document->createDocument ();
    my $eth_root = $new_eth_doc->createElement ('Theorems');

    $eth_root->setAttribute ('aid', $aid);
    $eth_root->appendText ("\n");
    my @theorem_nodes = $eth_doc->findnodes ('Theorems/Theorem');
    my $num_needed = 0;
    foreach my $theorem_node (@theorem_nodes) {
      unless ($theorem_node->exists ('@articlenr')) {
        print 'Error: we found a Theorem node that lacks an articlenr attribute!', "\n";
        exit 1;
      }
      unless ($theorem_node->exists ('@nr')) {
        print 'Error: we found a Theorem node that lacks an nr attribute!', "\n";
        exit 1;
      }
      unless ($theorem_node->exists ('@kind')) {
        print 'Error: we found a Theorem node that lacks a kind attribute!', "\n";
        exit 1;
      }
      my $articlenr = $theorem_node->findvalue ('@articlenr');
      my $nr = $theorem_node->findvalue ('@nr');
      my $kind = $theorem_node->findvalue ('@kind');
      if ($kind eq 'T') {
        if (defined $theorems{"${articlenr}:${nr}"}) {
          $num_needed++;
          $eth_root->appendChild ($theorem_node);
          $eth_root->appendText ("\n");
        }
      } elsif ($kind eq 'D') {
        if (defined $definitions{"${articlenr}:${nr}"}) {
          $num_needed++;
          $eth_root->appendChild ($theorem_node);
          $eth_root->appendText ("\n");
        }
      }
    }
    $new_eth_doc->setDocumentElement ($eth_root);
    $new_eth_doc->toFile ($article_eth);

    print 'done.  The initial environment contained ', scalar @theorem_nodes, ' elements, but we actually need only ', $num_needed, "\n";

  } else {
    print 'The .eth file does not exist for ', $article_basename, ', so there is nothing to minimize.', "\n";
    exit 1;
  }
}

# Ugh: This is nearly identical to the previous subroutine definition.
sub prune_schemes {
  my $refx_parser = XML::LibXML->new ();
  my $refx_doc = $refx_parser->parse_file ($article_refx);
  my %schemes = ();
  my @initial_sy_three_dots = $refx_doc->findnodes ('Parser/syThreeDots[not(preceding-sibling::sySemiColon)]');
  foreach my $sy_three_dots (@initial_sy_three_dots) {
    my $aid = $sy_three_dots->findvalue ('following-sibling::Int[1]/@x');
    my $nr = $sy_three_dots->findvalue ('following-sibling::Int[2]/@x');
    unless (defined $aid && defined $nr) {
      print 'Error: we failed to extract either the first or the second Int following an syThreeDots element!', "\n";
      exit 1;
    }
    $schemes{"$aid:$nr"} = 0;
  }
  if (-e $article_esh) {
    print 'Minimizing esh...';
    my $esh_parser = XML::LibXML->new ();
    my $esh_doc = $esh_parser->parse_file ($article_esh);

    # Create the new .esh document
    my $new_esh_doc = XML::LibXML::Document->createDocument ();
    my $esh_root = $new_esh_doc->createElement ('Schemes');

    $esh_root->setAttribute ('aid', $aid);
    $esh_root->appendText ("\n");
    my @scheme_nodes = $esh_doc->findnodes ('Schemes/Scheme');
    my $num_needed = 0;
    foreach my $scheme_node (@scheme_nodes) {
      unless ($scheme_node->exists ('@articlenr')) {
        print "\n";
        print 'Error: we found a Scheme node that lacks an articlenr attribute!', "\n";
        exit 1;
      }
      unless ($scheme_node->exists ('@nr')) {
        print "\n";
        print 'Error: we found a Scheme node that lacks an nr attribute!', "\n";
        exit 1;
      }
      my $articlenr = $scheme_node->findvalue ('@articlenr');
      my $nr = $scheme_node->findvalue ('@nr');
      if (defined $schemes{"${articlenr}:${nr}"}) {
        $num_needed++;
        $esh_root->appendChild ($scheme_node);
        $esh_root->appendText ("\n");
      }
    }
    $new_esh_doc->setDocumentElement ($esh_root);
    $new_esh_doc->toFile ($article_esh);

    print 'done.  The initial environment contained ', scalar @scheme_nodes, ' elements, but we actually need only ', $num_needed, "\n";

  } else {
    print 'The .esh file does not exist for ', $article_basename, ', so there is nothing to minimize.', "\n";
    exit 1;
  }
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

# Let's do it

prune_schemes ();
prune_theorems ();

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