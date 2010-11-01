=pod

=head1 NAME

IPC::Mutex - Mechanism for the synchronous processing

=head1 DESCRIPTION

現在このモジュールはアルファ版です。

このモジュールは、異なるプロセス間に於ける相互排他制御 Mutex を行うためのインタフェースを提供します。

=head1 ABSTRACT

This is the abstract class. Please see implemented sub classes.

このクラス IPC::Mutex は抽象クラスです。
機能を利用するためには、このインタフェースを実装したサブクラスを使います。

各サブクラスはその個性のために、追加パラメータを要するものもあります。
また前準備としてセッティングを必要とするものもありますが、
いずれにせよ、インスタンス化したオブジェクトのインタフェースは、
この抽象クラスに準じます。

各サブクラスの個性について、また準備するべき事柄については、
それぞれのサブクラスを参照してください。

現在、実装されているサブクラスは次のものがあります：

    IPC::Mutex::Flock
    IPC::Mutex::ShareLite

=head1 USAGE

First, choose the implementation sub class.
And next, make instance and just do critical() method giving an argument that is a closure.

    use IPC::Mutex::Flock;
    
    my $im = IPC::Mutex::Flock->new;
    my @results = $im->critical( sub {
        # task for exclusive other processes
        # ...
        return @val;
    } );

最初にどの実装を用いるか、用意されている実装サブクラスの中から選びます。

IPC::Mutex::Flock は flock 関数を用いて、
また IPC::Mutex::ShareLite は共有メモリを用いて、
クリティカルセクションのアトミック性を確保します。

そのオブジェクトを生成し、あとは使うだけです。
メソッド critical() に、
排他制御すべきコードブロックを持ったクロージャ（ CODE リファレンス）を渡して実行します。
このクロージャは、配列を返却するようにしなければなりません。

Note it though the return value of critical() is a return value of the closure
returns only the first element for the scalar context.

It is equal to the return of the closure for the list context. 

critical() の戻り値は、クロージャの戻り値ですが、
注意しなければならないのは、スカラーコンテキストの場合はその最初の要素だけを返します。
リストコンテキストの場合はクロージャの戻りと同等です。

=head1 INTERVAL MODE

If a parameter "interval" was given, the instance processing in "interval mode".
This mode breaking critical section at the seconds.

interval に秒をセットすると、クリティカルセクションに入ったプロセスは、
interval 秒が経過した時点で、実行を続けながらも、排他性を破棄します。
言い換えると、 interval 秒後に、ほかのプロセスがクリティカルセクションに入る事を許します。
（このときもはや Mutex とはいえない状況になります。）

これはたとえば、ウェブサーバに対して複数のクライアントがありながらも、
HTTP リクエストを１秒１リクエスト未満に抑えなければならない場合など、
単位時間あたりの処理数が限られている場合の制御に用いることができます。
（実のところこのモジュールは、その目標のために作成された、という経緯があります。）

なおこの処理を実現するために、シグナル ALRM を利用しているため、
クリティカルセクション内で実行する手続きの中で（ critical に渡すクロージャ内で）
シグナル ALRM を操作してはいけません。

=head1 CONSTRUCTOR

Method new() accepts an hash reference to configure.

コンストラクタ new は、ひとつのハッシュリファレンスを、設定パラメータとして受け付けます。

=over 4

=item key

名前空間を定めます。

key によって類される、異なる名前空間同士はお互いに排他に関する干渉がなされません。

なお IPC::ShareLite のために、
これは４桁までの、数値か文字列でなければなりません。

初期値は 1234 です。

=item delay

クリティカルセクションをロックしたプロセスが処理を終え、
そして最後にアンロック（クリティカルセクションの解放）を行う、
そのまさに直前に、 delay 秒の待ち時間を差し挟みます。

初期値はゼロです。

=item interval

真の値となる秒数をセットすると、 Interval モードで動作させます。

INTERVAL MODE の説明を参照してください。

なおこの値の秒数については、実は浮動小数を設定できますが、
その精度については 1/10 秒までがせいぜいではないでしょうか？

=back

=head1 METHODS

=head2 critical

Make a critical section for the "key".

Method critical() takes an argument that is a CODE reference, it going to process in mutex.

引数に渡されたクロージャ（ CODE リファレンス）を排他制御しつつ実行します。
あとから critical() を実行しようとするプロセスは待たされます。

クロージャの戻り値は配列でなければなりません。

critical() の戻り値はクロージャの戻り値ですが、
スカラコンテキストでは、クロージャの返す配列の最初の要素になります。

なお key が異なるインスタンスに対しては、排他の対象にはなりません。
key についての説明を参照してください。

=head2 cleanup

共有されているメモリ空間を片付けます。たとえば、 Flock ではロックファイルを削除します。

これはプロセスの終了の毎に実行させるものではないでしょう。

ロックファイルを作成したそのプロセス自身が終了しても、
同じロックファイルを用いる（ key が同じ）別プロセスが参照しているかもしれません。

=head1 SEE ALSO

L<IPC::Mutex::Flock>
L<IPC::Mutex::ShareLite>

=head1 AUTHOR

WATANABE Hiroaki, E<lt>hwat@mac.comE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package IPC::Mutex;

use strict;

use vars qw($VERSION $DEFAULT_KEY);
$VERSION = '0.01_01';
$DEFAULT_KEY = 1234;

use Carp;
use Time::HiRes;

sub new {
    my $class = shift;
    $class = ref $class || $class;
    my $self = {
        'key'       => undef,
        'delay'     => undef,
        'interval'  => undef,
        };
    bless $self, $class;
    return $self->_init(@_);
}

sub _init {
    my $self = shift;
    my $args = shift || {};
    $self->key( defined $args->{'key'} ? $args->{'key'} : $DEFAULT_KEY );
    $self->delay( defined $args->{'delay'} ? $args->{'delay'} : 0 );
    $self->interval( $args->{'interval'} );
    return $self;
}

sub _validate {
    my $self = shift;
    my $task = shift;
    
    my $err  = undef;

    if( ! $task ){
        $err = "missing task\n";
    }elsif( ref $task ne 'CODE' ){
        $err = "task is not CODE ref\n";
    }elsif( ! IPC::Mutex::_looks_like_number($self->delay) ){
        $err = "invalid value of delay\n";
    }elsif( defined $self->interval and ! IPC::Mutex::_looks_like_number($self->interval) ){
        $err = "invalid value of interval\n";
    }

    return $err;
}

sub key {
    my $self = shift;
    return @_ ? $self->{'key'} = shift : $self->{'key'};
}

sub delay {
    my $self = shift;
    return @_ ? $self->{'delay'} = shift : $self->{'delay'};
}

sub interval {
    my $self = shift;
    return @_ ? $self->{'interval'} = shift : $self->{'interval'};
}

sub critical {
    my $self    = shift;
    my $task    = shift;
    my @args    = @_;

    my $msg = $self->_validate($task);
    if( $msg ){
        Carp::croak "$msg";
    }
    
    #-- make critical section
    my $release_lock = $self->_lock_();
 
    my $t0;
    my $remain;
    my @return_value;
    unless( defined $self->interval ){
        @return_value = $task->(@args);
        $t0 = [Time::HiRes::gettimeofday];

        $remain = $self->delay;

    }else{
        local $SIG{'ALRM'} = sub {
                $release_lock->();
                $release_lock = sub {};
            };
        Time::HiRes::setitimer(Time::HiRes::ITIMER_REAL(), $self->interval, 0);
        $t0 = [Time::HiRes::gettimeofday];
        @return_value = $task->(@args);
        Time::HiRes::setitimer(Time::HiRes::ITIMER_REAL(), 0);

        $remain = $self->interval - Time::HiRes::tv_interval($t0);
    }

    Time::HiRes::sleep($remain) if( 0 < $remain );
 
    $release_lock->();  

    return wantarray ? @return_value : shift @return_value;
}

sub _lock_ {
    my $self = shift;
    my $pkg = ref $self;
    Carp::croak "$pkg"."::critical() is not be implemented yet";
}
sub cleanup {}

# _looks_like_number() is a copy of Scalar::Util::looks_like_number by Graham Barr.
# see the url for details:
# http://cpansearch.perl.org/src/GBARR/Scalar-List-Utils-1.23/lib/Scalar/Util/PP.pm
sub _looks_like_number {
  local $_ = shift;

  # checks from perlfaq4
  return 0 if !defined($_);
  if (ref($_)) {
    require overload;
    return overload::Overloaded($_) ? defined(0 + $_) : 0;
  }
  return 1 if (/^[+-]?[0-9]+$/); # is a +/- integer
  return 1 if (/^([+-]?)(?=[0-9]|\.[0-9])[0-9]*(\.[0-9]*)?([Ee]([+-]?[0-9]+))?$/); # a C float
  return 1 if ($] >= 5.008 and /^(Inf(inity)?|NaN)$/i) or ($] >= 5.006001 and /^Inf$/i);

  0;
}

1;
