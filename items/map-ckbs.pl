#!/usr/bin/perl -w

use strict;
use File::Basename qw(basename);
use XML::LibXML;

unless (scalar @ARGV == 1) {
  print 'Usage: map-ckbs.pl ITEMIZED-ARTICLE-DIRECTORY', "\n";
  exit 1;
}

my $article_dir = $ARGV[0];

unless (-d $article_dir) {
  print 'Error: ', $article_dir, ' is not a directory.', "\n";
  exit 1;
}

my $article_basename = basename ($article_dir);

my $prel_subdir = "${article_dir}/prel";

unless (-d $prel_subdir) {
  print 'Error: the prel subdirectory of ', $article_dir, ' does not exist.', "\n";
  exit 1;
}

# Constructors

my @dcos = `find $prel_subdir -name "*.dco" -exec basename {} .dco ';' | sed -e 's/ckb//' | sort --numeric-sort`;
chomp @dcos;

my %constructors = ();

foreach my $i (1 .. scalar @dcos) {
  my $dco = $dcos[$i - 1];
  my $dco_path = "$prel_subdir/ckb${dco}.dco";
  my $constructor_line = `grep '<Constructor ' $dco_path`;
  chomp $constructor_line;
  $constructor_line =~ m/ kind=\"(.)\"/;
  my $kind = $1;
  unless (defined $kind) {
    print 'Error: we failed to extract a kind attribute from the Constructor XML element', "\n", "\n", '  ', $constructor_line, "\n";
  }
  my $kind_lc = lc $kind;
  my $num;
  if (defined $constructors{$kind}) {
    $num = $constructors{$kind};
    $constructors{$kind} = $num + 1;
  } else {
    $num = 1;
    $constructors{$kind} = 2;
  }
  print $article_basename, ':', 'fragment', ':', $dco, ' => ', $article_basename, ':', $kind_lc, 'constructor', ':', $num, "\n";
}

# Definientia

my @defs = `find $prel_subdir -name "*.def" -exec basename {} .def ';' | sed -e 's/ckb//' | sort --numeric-sort`;
chomp @defs;

my %definiens = ();

foreach my $i (1 .. scalar @defs) {
  my $def = $defs[$i - 1];
  my $def_path = "$prel_subdir/ckb${def}.def";
  my $definiens_line = `grep '<Definiens ' $def_path`;
  chomp $definiens_line;
  $definiens_line =~ m/ constrkind=\"(.)\"/;
  my $constrkind = $1;
  unless (defined $constrkind) {
    print 'Error: we failed to extract a constrkind attribute from the Definiens XML element', "\n", "\n", '  ', $definiens_line, "\n";
  }
  my $constrkind_lc = lc $constrkind;
  my $num;
  if (defined $definiens{$constrkind}) {
    $num = $definiens{$constrkind};
    $definiens{$constrkind} = $num + 1;
  } else {
    $num = 1;
    $definiens{$constrkind} = 2;
  }
  print $article_basename, ':', 'fragment', ':', $def, ' => ', $article_basename, ':', $constrkind_lc, 'definiens', ':', $num, "\n";
}


# Deftheorems

my @thes = `grep --with-filename '<Theorem kind="D"' $prel_subdir/*.the | cut -f 1 -d ':' | parallel basename {} .the | sed -e 's/ckb//' | sort --numeric-sort`;
chomp @thes;

my %deftheorems = ();

foreach my $i (1 .. scalar @thes) {
  my $the = $thes[$i - 1];
  print $article_basename, ':', 'fragment', ':', $the, ' => ', $article_basename, ':', 'deftheorem' , ':', $i, "\n";
}

# Schemes

my @schs = `find $prel_subdir -name "*.sch" -exec basename {} .sch ';' | sed -e 's/ckb//' | sort --numeric-sort`;
chomp @schs;

my %schemes = ();

foreach my $i (1 .. scalar @schs) {
  my $sch = $schs[$i - 1];
  my $sch_path = "$prel_subdir/ckb${sch}.sch";
  print $article_basename, ':', 'fragment', ':', $sch, ' => ', $article_basename, ':', 'scheme', ':', $i, "\n";
}

# Clusters

my @dcls = `find $prel_subdir -name "*.dcl" -exec basename {} .dcl ';' | sed -e 's/ckb//' | sort --numeric-sort`;
chomp @dcls;

my %clusters = ();

foreach my $i (1 .. scalar @dcls) {
  my $dcl = $dcls[$i - 1];
  my $dcl_path = "$prel_subdir/ckb${dcl}.dcl";
  my $cluster_line = `grep '<[CFR]Cluster ' $dcl_path`;
  chomp $cluster_line;
  $cluster_line =~ m/([CFR])Cluster /;
  my $kind = $1;
  unless (defined $kind) {
    print 'Error: we failed to extract the cluster kind from the XML element', "\n", "\n", '  ', $cluster_line, "\n";
    exit 1;
  }
  my $kind_lc = lc $kind;
  my $num;
  if (defined $clusters{$kind}) {
    $num = $clusters{$kind};
    $clusters{$kind} = $num + 1;
  } else {
    $num = 1;
    $clusters{$kind} = 2;
  }
  print $article_basename, ':', 'fragment', ':', $dcl, ' => ', $article_basename, ':', $kind_lc, 'cluster', ':', $num, "\n";
}

# Notations

# Theorems and deftheorems

my @dnos = `find $prel_subdir -name "*.dno" -exec basename {} .dno ';' | sed -e 's/ckb//' | sort --numeric-sort`;
chomp @dnos;

my %patterns = ();

foreach my $i (1 .. scalar @dnos) {
  my $dno = $dnos[$i - 1];
  my $dno_path = "$prel_subdir/ckb${dno}.dno";
  my $pattern_line = `grep '<Pattern ' $dno_path`;
  chomp $pattern_line;
  $pattern_line =~ m/ constrkind=\"(.)\"/;
  my $constrkind = $1;
  unless (defined $constrkind) {
    print 'Error: we failed to extract a kind attribute from dno Pattern XML element', "\n", "\n", '  ', $pattern_line, "\n";
  }
  my $constrkind_lc = lc $constrkind;
  my $num;
  if (defined $patterns{$constrkind}) {
    $num = $patterns{$constrkind};
    $patterns{$constrkind} = $num + 1;
  } else {
    $num = 1;
    $patterns{$constrkind} = 2;
  }
  print $article_basename, ':', 'fragment', ':', $dno, ' => ', $article_basename, ':', $constrkind_lc, 'pattern', ':', $num, "\n";
}

# Theorems

my $article_wsx = "${article_dir}/${article_basename}.wsx";

unless (-e $article_wsx) {
  print 'Error: the .wsx for ', $article_basename, ' does not exist at the expected location (', $article_wsx, ').', "\n";
  exit 1;
}

# Create the split-and-itemized wsx

my $article_wsx_split_itemized = "${article_dir}/${article_basename}.wsxsi";

my $split_stylesheet = '/Users/alama/sources/mizar/xsl4mizar/items/split.xsl';
my $itemize_stylesheet = '/Users/alama/sources/mizar/xsl4mizar/items/itemize.xsl';

unless (-e $article_wsx_split_itemized) {
  my $xsltproc_status =
    system ("xsltproc $split_stylesheet $article_wsx | xsltproc --output $article_wsx_split_itemized $itemize_stylesheet -");
  my $xsltproc_exit_code = $xsltproc_status >> 8;
  if ($xsltproc_exit_code != 0) {
    print 'Error: something went wrong creating the split-and-itemized wsx for ', $article_basename, '.', "\n";
    exit 1;
  }
}

my $xml_parser = XML::LibXML->new();
my $wsx_doc = $xml_parser->parse_file ("$article_wsx_split_itemized");

my @theorems = $wsx_doc->findnodes ('Fragments/Text-Proper/Item[@kind = "Theorem-Item" and @promoted-lemma = "no"]');

# DEBUG
# print 'Found ', scalar @theorems, ' theorems', "\n";

foreach my $theorem (@theorems) {
  if ($theorem->exists ('@theorem-number')) {
    my $theorem_number = $theorem->findvalue ('@theorem-number');
    my $fragment_number = $theorem->findvalue ('count (preceding::Text-Proper) + 1');
    print $article_basename, ':', 'fragment', ':', $fragment_number, ' => ', $article_basename, ':', 'theorem', ':', $theorem_number, "\n";
  } else {
    print 'Error: we did not find the theorem-number attribute for a theorem!', "\n";
    exit 1;
  }
}

# Exported lemmas that were originally unexported

my @lemmas = $wsx_doc->findnodes ('Fragments/Text-Proper/Item[@kind = "Theorem-Item" and @promoted-lemma = "yes"]');

# DEBUG
# print 'Found ', scalar @lemmas, ' lemmas', "\n";

foreach my $lemma (@lemmas) {
  if ($lemma->exists ('@lemma-number')) {
    my $lemma_number = $lemma->findvalue ('@lemma-number');
    my $fragment_number = $lemma->findvalue ('count (preceding::Text-Proper) + 1');
    print $article_basename, ':', 'fragment', ':', $fragment_number, ' => ', $article_basename, ':', 'lemma', ':', $lemma_number, "\n";
  } else {
    print 'Error: we did not find the lemma-number attribute for a promoted lemma!', "\n";
    exit 1;
  }
}

# Unexportable lemmas that were originally unexported

my @unexportable_lemmas = $wsx_doc->findnodes ('Fragments/Text-Proper/Item[@kind = "Regular-Statement" and @exportable = "no" and not(following-sibling::*)]');

# DEBUG
# print 'Found ', scalar @unexportable_lemmas, ' unexportable lemmas', "\n";

foreach my $lemma (@unexportable_lemmas) {
  if ($lemma->exists ('@lemma-number')) {
    my $lemma_number = $lemma->findvalue ('@lemma-number');
    my $fragment_number = $lemma->findvalue ('count (preceding::Text-Proper) + 1');
    print $article_basename, ':', 'fragment', ':', $fragment_number, ' => ', $article_basename, ':', 'lemma', ':', $lemma_number, "\n";
  } else {
    print 'Error: we did not find the lemma-number attribute for an unpromoted lemma!', "\n";
    exit 1;
  }
}
