<?php

namespace App\Http\Requests\Commerce;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Listing Update Request
 * 
 * Validation for updating an existing listing.
 */
final class ListingUpdateRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        // Authorization handled by middleware and service layer (tenant boundary)
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     */
    public function rules(): array
    {
        return [
            'title' => 'sometimes|required|string|max:120',
            'description' => 'sometimes|nullable|string|max:5000',
            'price_amount' => 'sometimes|required|numeric|min:0',
            'currency' => 'sometimes|required|string|size:3',
        ];
    }
}





