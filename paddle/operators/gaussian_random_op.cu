/* Copyright (c) 2016 PaddlePaddle Authors. All Rights Reserve.
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
   http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License. */

#include <thrust/device_ptr.h>
#include <thrust/iterator/counting_iterator.h>
#include <thrust/random.h>
#include <thrust/transform.h>
#include "paddle/framework/op_registry.h"
#include "paddle/framework/operator.h"

namespace paddle {
namespace operators {

template <typename T>
struct GaussianGenerator {
  T mean_, std_;
  unsigned int seed_;

  __host__ __device__ GaussianGenerator(T mean, T std, int seed)
      : mean_(mean), std_(std), seed_(seed) {}

  __host__ __device__ T operator()(const unsigned int n) const {
    thrust::minstd_rand rng;
    rng.seed(seed_);
    thrust::normal_distribution<T> dist(mean_, std_);
    rng.discard(n);
    return dist(rng);
  }
};

template <typename T>
class GPUGaussianRandomKernel : public framework::OpKernel {
 public:
  void Compute(const framework::ExecutionContext& context) const override {
    auto* tensor = context.Output<framework::Tensor>("Out");
    T* data = tensor->mutable_data<T>(context.GetPlace());
    unsigned int seed =
        static_cast<unsigned int>(context.op_.GetAttr<int>("seed"));
    if (seed == 0) {
      std::random_device rd;
      seed = rd();
    }
    T mean = static_cast<T>(context.op_.GetAttr<float>("mean"));
    T std = static_cast<T>(context.op_.GetAttr<float>("std"));
    thrust::counting_iterator<unsigned int> index_sequence_begin(0);
    ssize_t N = framework::product(tensor->dims());
    thrust::transform(index_sequence_begin, index_sequence_begin + N,
                      thrust::device_ptr<T>(data),
                      GaussianGenerator<T>(mean, std, seed));
  }
};

}  // namespace operators
}  // namespace paddle

REGISTER_OP_GPU_KERNEL(gaussian_random,
                       paddle::operators::GPUGaussianRandomKernel<float>);

