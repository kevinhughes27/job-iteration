# frozen_string_literal: true

require "test_helper"
require "sorbet-runtime"

class JobIterationTest < IterationUnitTest
  class JobWithNoMethods < ActiveJob::Base
    include JobIteration::Iteration
  end

  class JobWithRightMethods < ActiveJob::Base
    include JobIteration::Iteration
    def build_enumerator(_params, cursor:)
      enumerator_builder.build_times_enumerator(2, cursor: cursor)
    end

    def each_iteration(*)
    end
  end

  class JobWithRightMethodsButWithSorbetSignatures < ActiveJob::Base
    extend T::Sig
    include JobIteration::Iteration

    sig { params(_params: T.untyped, cursor: T.untyped).returns(T::Enumerator[T.untyped]) }
    def build_enumerator(_params, cursor:)
      enumerator_builder.build_times_enumerator(2, cursor: cursor)
    end

    sig { params(product: T.untyped, params: T.untyped).void }
    def each_iteration(product, params)
    end
  end

  class JobWithRightMethodsButMissingCursorKeywordArgument < ActiveJob::Base
    include JobIteration::Iteration
    def build_enumerator(params, cursor)
      enumerator_builder.active_record_on_records(
        Product.where(id: params[:id]),
        cursor: cursor,
      )
    end

    def each_iteration(product, params)
    end
  end

  class JobWithRightMethodsUsingSplatInTheArguments < ActiveJob::Base
    include JobIteration::Iteration
    def build_enumerator(*)
    end

    def each_iteration(*)
    end
  end

  class JobWithRightMethodsUsingDefaultKeywordArgument < ActiveJob::Base
    include JobIteration::Iteration
    def build_enumerator(params, cursor: nil)
    end

    def each_iteration(*)
    end
  end

  def test_jobs_that_define_build_enumerator_and_each_iteration_will_not_raise
    push(JobWithRightMethods, 'walrus' => 'best')
    work_one_job
  end

  def test_jobs_that_define_build_enumerator_and_each_iteration_with_sigs_will_not_raise
    push(JobWithRightMethodsButWithSorbetSignatures, 'walrus' => 'best')
    work_one_job
  end

  def test_jobs_that_pass_splat_argument_to_build_enumerator_will_not_raise
    push(JobWithRightMethodsUsingSplatInTheArguments, {})
    work_one_job
  end

  def test_jobs_that_pass_default_keyword_argument_to_build_enumerator_will_not_raise
    push(JobWithRightMethodsUsingDefaultKeywordArgument, {})
    work_one_job
  end

  def test_jobs_that_do_not_define_build_enumerator_or_each_iteration_raises
    assert_raises(ArgumentError) do
      push(JobWithNoMethods)
    end
  end

  def test_jobs_that_defines_methods_but_do_not_declare_cursor_as_keyword_argument_raises
    assert_raises(ArgumentError) do
      push(JobWithRightMethodsButMissingCursorKeywordArgument, id: 1)
    end
  end

  def test_that_it_has_a_version_number
    refute_nil(::JobIteration::VERSION)
  end

  private

  def push(job, *args)
    job.perform_later(*args)
  end

  def work_one_job
    job = ActiveJob::Base.queue_adapter.enqueued_jobs.pop
    ActiveJob::Base.execute(job)
  end
end
