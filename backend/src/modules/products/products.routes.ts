import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { customFieldsController } from '../customFields/customFields.controller.js';
import { productsController } from './products.controller.js';

const router = Router();

router.post('/', asyncHandler(productsController.create.bind(productsController)));
router.get('/', asyncHandler(productsController.list.bind(productsController)));
router.get('/lookup', asyncHandler(productsController.lookup.bind(productsController)));
router.get('/catalogue', asyncHandler(productsController.catalogue.bind(productsController)));
router.get('/:id', asyncHandler(productsController.getById.bind(productsController)));
router.patch('/:id', asyncHandler(productsController.update.bind(productsController)));
router.post('/:id/publish', asyncHandler(productsController.setPublished.bind(productsController)));
router.delete('/:id', asyncHandler(productsController.delete.bind(productsController)));

router.post('/:id/images', asyncHandler(productsController.addImage.bind(productsController)));
router.delete('/:id/images/:imageId', asyncHandler(productsController.deleteImage.bind(productsController)));
router.patch('/:id/images/reorder', asyncHandler(productsController.reorderImages.bind(productsController)));

router.get(
  '/:id/custom-fields',
  asyncHandler(customFieldsController.listValuesForProduct.bind(customFieldsController)),
);
router.put(
  '/:id/custom-fields',
  asyncHandler(customFieldsController.bulkSetValuesForProduct.bind(customFieldsController)),
);
router.put(
  '/:id/custom-fields/:definitionId',
  asyncHandler(customFieldsController.setValueForProduct.bind(customFieldsController)),
);
router.delete(
  '/:id/custom-fields/:definitionId',
  asyncHandler(customFieldsController.deleteValueForProduct.bind(customFieldsController)),
);

export default router;
