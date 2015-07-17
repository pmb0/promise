use strict;
use warnings;
use experimental 'signatures';

use Data::Dumper;
use Promise;
use Test::More;

my $p = Promise->new;
my $v;
$p->done(sub($value) { $v = $value });
is $v, undef;
$p->resolve(123);
is $v, 123;
$p->resolve('abc');
is $v, 123;

$p = Promise->new(sub($resolve, $reject) { $resolve->(111); });
is $p->_value, 111;

$p = Promise->new(sub($resolve, $reject) { $reject->('err'); });
is $p->_value, 'err';

$p = Promise->new(sub($resolve, $reject) { $resolve->(333); });
$p->then(sub($value) { return $value + 1 });
is $p->_value, 334;

# $Data::Dumper::Deparse = 1;
# warn Data::Dumper::Dumper($p);

done_testing();
