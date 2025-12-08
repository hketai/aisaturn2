<script setup>
import { computed, onMounted, ref, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Textarea from 'dashboard/components-next/textarea/Textarea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import saturnProductAPI from 'dashboard/api/saturn/product';

const { t } = useI18n();
const alert = useAlert();

const products = ref([]);
const isFetching = ref(false);
const searchQuery = ref('');
const sourceFilter = ref('all');
const currentPage = ref(1);
const totalPages = ref(1);
const totalCount = ref(0);

// Dialog refs
const createDialogRef = ref(null);
const editDialogRef = ref(null);
const deleteDialogRef = ref(null);

// Form state
const isSubmitting = ref(false);
const selectedProduct = ref(null);
const productForm = ref({
  title: '',
  description: '',
  min_price: '',
  max_price: '',
  total_inventory: 0,
  vendor: '',
  product_type: '',
});

const isEmpty = computed(() => !products.value.length && !isFetching.value);

const sourceOptions = [
  { value: 'all', label: 'Tümü' },
  { value: 'manual', label: 'Manuel' },
  { value: 'shopify', label: 'Shopify' },
];

const fetchProducts = async () => {
  isFetching.value = true;
  try {
    const params = {
      page: currentPage.value,
      perPage: 25,
    };
    if (sourceFilter.value !== 'all') {
      params.source = sourceFilter.value;
    }
    if (searchQuery.value) {
      params.query = searchQuery.value;
    }

    const response = await saturnProductAPI.get(params);
    products.value = response.data.products || [];
    totalPages.value = response.data.meta?.total_pages || 1;
    totalCount.value = response.data.meta?.total_count || 0;
  } catch (error) {
    console.error('Error fetching products:', error);
    alert.show(t('SATURN.PRODUCTS.FETCH_ERROR'), 'error');
  } finally {
    isFetching.value = false;
  }
};

const handleSearch = () => {
  currentPage.value = 1;
  fetchProducts();
};

const handleSourceChange = event => {
  sourceFilter.value = event.target.value;
  currentPage.value = 1;
  fetchProducts();
};

const openCreateDialog = () => {
  resetForm();
  createDialogRef.value?.open();
};

const openEditDialog = product => {
  selectedProduct.value = product;
  productForm.value = {
    title: product.title || '',
    description: product.description || '',
    min_price: product.min_price || '',
    max_price: product.max_price || '',
    total_inventory: product.total_inventory || 0,
    vendor: product.vendor || '',
    product_type: product.product_type || '',
  };
  editDialogRef.value?.open();
};

const openDeleteDialog = product => {
  selectedProduct.value = product;
  deleteDialogRef.value?.open();
};

const resetForm = () => {
  productForm.value = {
    title: '',
    description: '',
    min_price: '',
    max_price: '',
    total_inventory: 0,
    vendor: '',
    product_type: '',
  };
  selectedProduct.value = null;
};

const handleCreate = async () => {
  if (!productForm.value.title) {
    alert.show(t('SATURN.PRODUCTS.TITLE_REQUIRED'), 'error');
    return;
  }

  isSubmitting.value = true;
  try {
    await saturnProductAPI.create(productForm.value);
    alert.show(t('SATURN.PRODUCTS.CREATE_SUCCESS'), 'success');
    createDialogRef.value?.close();
    fetchProducts();
  } catch (error) {
    console.error('Error creating product:', error);
    alert.show(t('SATURN.PRODUCTS.CREATE_ERROR'), 'error');
  } finally {
    isSubmitting.value = false;
  }
};

const handleUpdate = async () => {
  if (!productForm.value.title) {
    alert.show(t('SATURN.PRODUCTS.TITLE_REQUIRED'), 'error');
    return;
  }

  isSubmitting.value = true;
  try {
    await saturnProductAPI.update(selectedProduct.value.id, productForm.value);
    alert.show(t('SATURN.PRODUCTS.UPDATE_SUCCESS'), 'success');
    editDialogRef.value?.close();
    fetchProducts();
  } catch (error) {
    console.error('Error updating product:', error);
    alert.show(t('SATURN.PRODUCTS.UPDATE_ERROR'), 'error');
  } finally {
    isSubmitting.value = false;
  }
};

const handleDelete = async () => {
  isSubmitting.value = true;
  try {
    await saturnProductAPI.delete(selectedProduct.value.id);
    alert.show(t('SATURN.PRODUCTS.DELETE_SUCCESS'), 'success');
    deleteDialogRef.value?.close();
    fetchProducts();
  } catch (error) {
    console.error('Error deleting product:', error);
    alert.show(t('SATURN.PRODUCTS.DELETE_ERROR'), 'error');
  } finally {
    isSubmitting.value = false;
  }
};

const formatPrice = price => {
  if (!price) return '-';
  return `₺${parseFloat(price).toFixed(2)}`;
};

const getSourceBadgeClass = source => {
  const classes = {
    manual: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
    shopify: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-300',
    woocommerce: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300',
    trendyol: 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-300',
  };
  return classes[source] || 'bg-gray-100 text-gray-800';
};

onMounted(() => {
  fetchProducts();
});
</script>

<template>
  <SaturnPageLayout
    :page-title="$t('SATURN.PRODUCTS.HEADER')"
    :action-button-text="$t('SATURN.PRODUCTS.ADD_NEW')"
    :action-permissions="['administrator']"
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="isEmpty"
    :total-records="totalCount"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    @action="openCreateDialog"
  >
    <template #emptyStateSection>
      <div class="flex flex-col items-center justify-center py-16">
        <div class="w-16 h-16 mb-4 rounded-full bg-n-slate-3 flex items-center justify-center">
          <svg class="w-8 h-8 text-n-slate-11" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
          </svg>
        </div>
        <h3 class="text-lg font-medium text-n-slate-12 mb-2">
          {{ $t('SATURN.PRODUCTS.EMPTY_TITLE') }}
        </h3>
        <p class="text-n-slate-11 mb-4">
          {{ $t('SATURN.PRODUCTS.EMPTY_DESCRIPTION') }}
        </p>
        <Button @click="openCreateDialog">
          {{ $t('SATURN.PRODUCTS.ADD_FIRST') }}
        </Button>
      </div>
    </template>

    <template #topControls>
      <div class="flex flex-col sm:flex-row gap-3 mb-4">
        <div class="flex-1">
          <Input
            v-model="searchQuery"
            :placeholder="$t('SATURN.PRODUCTS.SEARCH_PLACEHOLDER')"
            @keyup.enter="handleSearch"
          />
        </div>
        <select
          :value="sourceFilter"
          class="px-3 py-2 border border-n-slate-6 rounded-lg bg-n-solid-2 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          @change="handleSourceChange"
        >
          <option v-for="opt in sourceOptions" :key="opt.value" :value="opt.value">
            {{ opt.label }}
          </option>
        </select>
        <Button variant="secondary" @click="handleSearch">
          {{ $t('SATURN.PRODUCTS.SEARCH') }}
        </Button>
      </div>
    </template>

    <template #contentArea>
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr class="border-b border-n-slate-6">
              <th class="text-left py-3 px-4 text-sm font-medium text-n-slate-11">
                {{ $t('SATURN.PRODUCTS.TABLE.TITLE') }}
              </th>
              <th class="text-left py-3 px-4 text-sm font-medium text-n-slate-11">
                {{ $t('SATURN.PRODUCTS.TABLE.PRICE') }}
              </th>
              <th class="text-left py-3 px-4 text-sm font-medium text-n-slate-11">
                {{ $t('SATURN.PRODUCTS.TABLE.INVENTORY') }}
              </th>
              <th class="text-left py-3 px-4 text-sm font-medium text-n-slate-11">
                {{ $t('SATURN.PRODUCTS.TABLE.SOURCE') }}
              </th>
              <th class="text-right py-3 px-4 text-sm font-medium text-n-slate-11">
                {{ $t('SATURN.PRODUCTS.TABLE.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="product in products"
              :key="product.id"
              class="border-b border-n-slate-4 hover:bg-n-slate-2 transition-colors"
            >
              <td class="py-3 px-4">
                <div class="flex flex-col">
                  <span class="font-medium text-n-slate-12">{{ product.title }}</span>
                  <span v-if="product.vendor" class="text-sm text-n-slate-11">{{ product.vendor }}</span>
                </div>
              </td>
              <td class="py-3 px-4 text-n-slate-12">
                <span v-if="product.min_price === product.max_price">
                  {{ formatPrice(product.min_price) }}
                </span>
                <span v-else>
                  {{ formatPrice(product.min_price) }} - {{ formatPrice(product.max_price) }}
                </span>
              </td>
              <td class="py-3 px-4">
                <span
                  :class="product.total_inventory > 0 ? 'text-green-600' : 'text-red-600'"
                >
                  {{ product.total_inventory || 0 }}
                </span>
              </td>
              <td class="py-3 px-4">
                <span
                  :class="getSourceBadgeClass(product.source)"
                  class="px-2 py-1 text-xs font-medium rounded-full"
                >
                  {{ product.source }}
                </span>
              </td>
              <td class="py-3 px-4 text-right">
                <div class="flex items-center justify-end gap-2">
                  <button
                    v-if="product.editable"
                    class="p-1.5 text-n-slate-11 hover:text-n-slate-12 hover:bg-n-slate-3 rounded transition-colors"
                    @click="openEditDialog(product)"
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                  </button>
                  <button
                    v-if="product.editable"
                    class="p-1.5 text-red-500 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 rounded transition-colors"
                    @click="openDeleteDialog(product)"
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                  <span
                    v-if="!product.editable"
                    class="text-xs text-n-slate-10"
                  >
                    {{ $t('SATURN.PRODUCTS.READONLY') }}
                  </span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div v-if="totalPages > 1" class="flex items-center justify-between mt-4 pt-4 border-t border-n-slate-4">
        <span class="text-sm text-n-slate-11">
          {{ $t('SATURN.PRODUCTS.TOTAL_COUNT', { count: totalCount }) }}
        </span>
        <div class="flex gap-2">
          <Button
            variant="secondary"
            size="small"
            :disabled="currentPage === 1"
            @click="currentPage--; fetchProducts()"
          >
            {{ $t('SATURN.PRODUCTS.PREV') }}
          </Button>
          <span class="px-3 py-1 text-sm text-n-slate-11">
            {{ currentPage }} / {{ totalPages }}
          </span>
          <Button
            variant="secondary"
            size="small"
            :disabled="currentPage === totalPages"
            @click="currentPage++; fetchProducts()"
          >
            {{ $t('SATURN.PRODUCTS.NEXT') }}
          </Button>
        </div>
      </div>
    </template>

    <!-- Create Dialog -->
    <Dialog ref="createDialogRef" :title="$t('SATURN.PRODUCTS.CREATE_TITLE')">
      <div class="flex flex-col gap-4 p-4">
        <Input
          v-model="productForm.title"
          :label="$t('SATURN.PRODUCTS.FORM.TITLE')"
          :placeholder="$t('SATURN.PRODUCTS.FORM.TITLE_PLACEHOLDER')"
          required
        />
        <Textarea
          v-model="productForm.description"
          :label="$t('SATURN.PRODUCTS.FORM.DESCRIPTION')"
          :placeholder="$t('SATURN.PRODUCTS.FORM.DESCRIPTION_PLACEHOLDER')"
          rows="3"
        />
        <div class="grid grid-cols-2 gap-4">
          <Input
            v-model="productForm.min_price"
            :label="$t('SATURN.PRODUCTS.FORM.MIN_PRICE')"
            type="number"
            step="0.01"
            min="0"
          />
          <Input
            v-model="productForm.max_price"
            :label="$t('SATURN.PRODUCTS.FORM.MAX_PRICE')"
            type="number"
            step="0.01"
            min="0"
          />
        </div>
        <Input
          v-model="productForm.total_inventory"
          :label="$t('SATURN.PRODUCTS.FORM.INVENTORY')"
          type="number"
          min="0"
        />
        <div class="grid grid-cols-2 gap-4">
          <Input
            v-model="productForm.vendor"
            :label="$t('SATURN.PRODUCTS.FORM.VENDOR')"
            :placeholder="$t('SATURN.PRODUCTS.FORM.VENDOR_PLACEHOLDER')"
          />
          <Input
            v-model="productForm.product_type"
            :label="$t('SATURN.PRODUCTS.FORM.CATEGORY')"
            :placeholder="$t('SATURN.PRODUCTS.FORM.CATEGORY_PLACEHOLDER')"
          />
        </div>
        <div class="flex justify-end gap-3 mt-4">
          <Button variant="secondary" @click="createDialogRef?.close()">
            {{ $t('SATURN.PRODUCTS.CANCEL') }}
          </Button>
          <Button :loading="isSubmitting" @click="handleCreate">
            {{ $t('SATURN.PRODUCTS.CREATE') }}
          </Button>
        </div>
      </div>
    </Dialog>

    <!-- Edit Dialog -->
    <Dialog ref="editDialogRef" :title="$t('SATURN.PRODUCTS.EDIT_TITLE')">
      <div class="flex flex-col gap-4 p-4">
        <Input
          v-model="productForm.title"
          :label="$t('SATURN.PRODUCTS.FORM.TITLE')"
          :placeholder="$t('SATURN.PRODUCTS.FORM.TITLE_PLACEHOLDER')"
          required
        />
        <Textarea
          v-model="productForm.description"
          :label="$t('SATURN.PRODUCTS.FORM.DESCRIPTION')"
          :placeholder="$t('SATURN.PRODUCTS.FORM.DESCRIPTION_PLACEHOLDER')"
          rows="3"
        />
        <div class="grid grid-cols-2 gap-4">
          <Input
            v-model="productForm.min_price"
            :label="$t('SATURN.PRODUCTS.FORM.MIN_PRICE')"
            type="number"
            step="0.01"
            min="0"
          />
          <Input
            v-model="productForm.max_price"
            :label="$t('SATURN.PRODUCTS.FORM.MAX_PRICE')"
            type="number"
            step="0.01"
            min="0"
          />
        </div>
        <Input
          v-model="productForm.total_inventory"
          :label="$t('SATURN.PRODUCTS.FORM.INVENTORY')"
          type="number"
          min="0"
        />
        <div class="grid grid-cols-2 gap-4">
          <Input
            v-model="productForm.vendor"
            :label="$t('SATURN.PRODUCTS.FORM.VENDOR')"
            :placeholder="$t('SATURN.PRODUCTS.FORM.VENDOR_PLACEHOLDER')"
          />
          <Input
            v-model="productForm.product_type"
            :label="$t('SATURN.PRODUCTS.FORM.CATEGORY')"
            :placeholder="$t('SATURN.PRODUCTS.FORM.CATEGORY_PLACEHOLDER')"
          />
        </div>
        <div class="flex justify-end gap-3 mt-4">
          <Button variant="secondary" @click="editDialogRef?.close()">
            {{ $t('SATURN.PRODUCTS.CANCEL') }}
          </Button>
          <Button :loading="isSubmitting" @click="handleUpdate">
            {{ $t('SATURN.PRODUCTS.SAVE') }}
          </Button>
        </div>
      </div>
    </Dialog>

    <!-- Delete Dialog -->
    <Dialog ref="deleteDialogRef" :title="$t('SATURN.PRODUCTS.DELETE_TITLE')">
      <div class="p-4">
        <p class="text-n-slate-11 mb-4">
          {{ $t('SATURN.PRODUCTS.DELETE_CONFIRM', { title: selectedProduct?.title }) }}
        </p>
        <div class="flex justify-end gap-3">
          <Button variant="secondary" @click="deleteDialogRef?.close()">
            {{ $t('SATURN.PRODUCTS.CANCEL') }}
          </Button>
          <Button variant="danger" :loading="isSubmitting" @click="handleDelete">
            {{ $t('SATURN.PRODUCTS.DELETE') }}
          </Button>
        </div>
      </div>
    </Dialog>
  </SaturnPageLayout>
</template>

